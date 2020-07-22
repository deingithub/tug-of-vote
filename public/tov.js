document.addEventListener("DOMContentLoaded", function () {
    window.tov = {
        is_editing_revision: false,
        displayed_rev: null,
        rev_list_expanded: false,
    };

    if (window.localStorage["theme"]) {
        changeTheme(Number(window.localStorage["theme"]));
        document.querySelector("[data-js-select-theme]").selectedIndex = Number(window.localStorage["theme"]);
    }

    // Set up dangerous thing warnings
    document.querySelectorAll("[data-js-confirm]").forEach(function (thing) {
        thing.addEventListener("click", function (event) {
            if (!window.confirm(event.target.getAttribute("data-js-confirm"))) {
                event.preventDefault();
            }
        });
    });

    // Set up countdown
    if (document.querySelector("[data-js-countdown-to]")) {
        updateCountdown();
    }

    // Set up dynamic Poll/Ballot reload
    if (document.querySelector("section[class$=results]")) {
        window.setTimeout(fetchPollBallotUpdates, 5000);
    }

    document.querySelector("[data-js-select-theme]").addEventListener("change", function (event) {
        changeTheme(Number(event.target.value));
    });


    // Set up Docs UI
    if (document.querySelector(".cap-doc")) {
        setUpRevListUI();

        document.querySelector("[data-js-enable-doc-editing]").addEventListener("click", function (event) {
            event.preventDefault();
            if (window.tov.is_editing_revision) {
                if (!window.confirm("This will irretrivably discard your edits. Proceed?")) { return; }
            }
            toggleRevEditing(!window.tov.is_editing_revision)
        });

        document.querySelector("[data-js-doc-submit]").addEventListener("click", function (event) {
            event.preventDefault();

            // if we have an edit, add it to the form
            if (window.tov.is_editing_revision) {
                var newRev = document.querySelector(".cap-doc #editbox").value;
                document.querySelector('.revision input[name="new-rev"]').value = newRev;
                document.querySelector('.revision input[name="parent-rev"]').value = window.tov.displayed_rev || "";
            }

            // add auth data to form
            document.querySelector('.revision input[name="name"]').value = document.querySelector(".iam input#name").value;
            document.querySelector('.revision input[name="password"]').value = document.querySelector(".iam input#password").value;

            const fd = new FormData(document.querySelector(".revision form"));

            // abort if already processing some request
            if (document.querySelector(".cap-doc ol.req-in-flight")) { return; }
            document.querySelector(".cap-doc ol").classList.toggle("req-in-flight");

            fetch(window.location.pathname + "/doc/edit", { method: "POST", body: fd }).then(
                resp => {
                    update_rev_list(resp);
                    // reset submission fields
                    document.querySelector('.revision input[name="new-rev"]').value = "";
                    document.querySelector('.revision input[name="parent-rev"]').value = "";
                    // reset editing area
                    toggleRevEditing(false);
                    document.querySelector(".revision textarea#comment").value = "";
                }
            );
        });
    }
});

function update_rev_list(resp) {
    if (resp.status != 200) {
        const div = document.createElement("aside");
        resp.text().then(text => {
            document.querySelector(".cap-doc ol").classList.toggle("req-in-flight");
            div.innerHTML = text;
            alert(div.querySelector("p").innerHTML);
        });
        throw new Error("whoops");
    }
    resp.text().then(text => {
        const div = document.createElement("aside");
        div.innerHTML = text;
        old_revs = document.querySelectorAll(".cap-doc ol li details");
        div.querySelectorAll(".cap-doc ol li details").forEach((elem, index) => {
            if (!old_revs[index]) { return; }

            elem.open = old_revs[index].open;
            const view_link = elem.querySelector("summary a");
            if (view_link) {
                view_link.innerText = old_revs[index].querySelector("summary a").innerText;
            }
        });
        document.querySelector(".cap-doc ol").outerHTML = div.querySelector(".cap-doc ol").outerHTML;
        setUpRevListUI();
    });
}

function setUpRevListUI() {
    function makeItSo(thing, attribName, strToVote) {
        thing.addEventListener("click", function (event) {
            const fd = new FormData();
            const name = document.querySelector(".iam input#name").value;
            const password = document.querySelector(".iam input#password").value;
            if (!name || !password) {
                return;
            }
            fd.append("name", name);
            fd.append("password", password);
            fd.append("rev-id", event.target.getAttribute(attribName));
            fd.append("react", strToVote);

            if (document.querySelector(".cap-doc ol.req-in-flight")) { return; }
            document.querySelector(".cap-doc ol").classList.toggle("req-in-flight");
            fetch(window.location.pathname + "/doc/react", { method: "POST", body: fd })
                .then(resp => update_rev_list(resp));
        });
    }
    document.querySelectorAll("[data-js-react-rev-pro]").forEach(thing => {
        makeItSo(thing, "data-js-react-rev-pro", "infavor");
    });
    document.querySelectorAll("[data-js-react-rev-neu]").forEach(thing => {
        makeItSo(thing, "data-js-react-rev-neu", "neutral");
    });
    document.querySelectorAll("[data-js-react-rev-con]").forEach(thing => {
        makeItSo(thing, "data-js-react-rev-con", "against");
    });

    document.querySelectorAll("[data-js-focus-rev]").forEach(function (thing) {
        thing.addEventListener("click", function (event) {
            event.preventDefault();
            if (window.tov.is_editing_revision) {
                if (!window.confirm("Displaying this revision will irretrievably discard the edits you've made so far. Proceed?")) {
                    return;
                }
            }
            toggleRevEditing(false);

            const link = event.target.getAttribute("href");
            fetchRevision(link);
            window.tov.displayed_rev = link.split("/")[link.split("/").length - 1];
        });
    });

    document.querySelector("[data-js-toggle-revs]").addEventListener("click", function (event) {
        event.preventDefault();
        if (window.tov.rev_list_expanded) {
            event.target.innerText = "Expand All";
        } else {
            event.target.innerText = "Collapse All";
        }
        for (thing of document.querySelectorAll(".cap-doc ol li details")) {
            thing.open = !window.tov.rev_list_expanded;
        }
        window.tov.rev_list_expanded = !window.tov.rev_list_expanded;
    });

    document.querySelector("[data-js-refresh-revs]").addEventListener("click", function (event) {
        event.preventDefault();
        if (document.querySelector(".cap-doc ol.req-in-flight")) { return; }
        document.querySelector(".cap-doc ol").classList.toggle("req-in-flight");
        fetch(window.location).then(
            resp => update_rev_list(resp)
        );
    });
}

function updateCountdown() {
    const elem = document.querySelector("[data-js-countdown-to]");
    const then = new Date(Number(elem.getAttribute("data-js-countdown-to")));
    const now = Date.now();
    var diff = (then - now) / 1000 / 60;
    if (diff < 0) {
        elem.innerHTML = "Voting has ended.";
        document.querySelector(".object-actions .vote").remove();
    } else {
        const hours = Math.floor(diff / 60);
        const mins = Math.floor(diff % 60);
        elem.innerHTML = `Voting ends in ${hours}&nbsp;hour${hours == 1 ? '' : 's'} and ${mins}&nbsp;minute${mins == 1 ? '' : 's'}.`;
        window.setTimeout(updateCountdown, 5000);
    }
}

function fetchPollBallotUpdates() {
    fetch(window.location)
        .then(response => response.text())
        .then(text => {
            const div = document.createElement("section");
            div.innerHTML = text;
            // preserve countdown
            const countdownSelector = ".object-metadata [data-js-countdown-to]";
            if (div.querySelector(countdownSelector)) {
                div.querySelector(countdownSelector).outerHTML = document.querySelector(countdownSelector).outerHTML;
            }
            const resultSelector = "section[class$=results]";
            document.querySelector(resultSelector).outerHTML = div.querySelector(resultSelector).outerHTML;
            window.setTimeout(fetchPollBallotUpdates, 5000);
        });
}

function fetchRevision(link) {
    fetch(link)
        .then(response => response.text())
        .then(text => {
            const div = document.createElement("section");
            div.innerHTML = text;
            document.querySelector(".active-rev").outerHTML = div.querySelector(".active-rev").outerHTML;
            document.querySelectorAll("[data-js-focus-rev]").forEach(function (element) {
                if (element.getAttribute("href") == link) {
                    element.innerHTML = "Active";
                } else {
                    element.innerHTML = "View";
                }
            })
        });
}

function toggleRevEditing(status) {
    const rendered = document.querySelector("#rendered");
    const editbox = document.querySelector("#editbox");
    if (!editbox) { return; }

    if (status) {
        editbox.classList.remove("hidden");
        editbox.value = rendered.innerText;
        rendered.classList.add("hidden");
        document.querySelector("[data-js-enable-doc-editing]").innerText = "Revert Edits";
    } else {
        editbox.classList.add("hidden");
        editbox.value = "";
        rendered.classList.remove("hidden");
        document.querySelector("[data-js-enable-doc-editing]").innerText = "Edit currently displayed revision";
    }
    window.tov.is_editing_revision = status;
}

function changeTheme(selected) {
    const num_themes = 2;
    window.localStorage["theme"] = selected;
    const theme_start_index = document.styleSheets[0].cssRules.length - num_themes - 1;
    var index = 0;
    for (rule of document.styleSheets[0].cssRules) {
        if (index < theme_start_index) { index++; continue; }

        if (selected > 0 && index == theme_start_index + selected) {
            rule.conditionText = "screen";
        } else {
            rule.conditionText = "not all";
        }
        index++;
    }
}