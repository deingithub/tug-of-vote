document.addEventListener("DOMContentLoaded", function () {
    window.tov = {};
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

    // Set up Docs UI
    if (document.querySelector(".cap-doc")) {
        setUpRevListUI();

        document.querySelector("[data-js-enable-doc-editing]").addEventListener("click", function (event) {
            event.preventDefault();
            const revbox = document.querySelector(".cap-doc article");
            if (revbox.hasAttribute("contenteditable") && window.confirm("This will irretrievably discard the edits you've made so far. Proceed?")) {
                revbox.innerHTML = window.tov.old_rev_text;
                delete window.tov.old_rev_text;
                revbox.removeAttribute("contenteditable");
                event.target.innerText = "Edit currently displayed revision";
            } else {
                window.tov.old_rev_text = revbox.innerHTML;
                revbox.setAttribute("contenteditable", "");
                event.target.innerText = "Revert edits";
            }
        });

        document.querySelector("[data-js-doc-submit]").addEventListener("click", function (event) {
            event.preventDefault();
            if (window.tov.old_rev_text) {
                var newRev = document.querySelector(".cap-doc article[contenteditable]").innerText;

                // This is incomprehensibly cursed.
                // I do not understand why this is necessary.
                // I have given up trying to understand why this is necessary. 
                // I would not wish dealing with this utterly disgusting mess
                // upon Brendan Eich himself.
                newRev = newRev.replace(/(?:\r?\n){2}/g, "\n");
                newRev = newRev.replace(/(?:\r?\n){3}/g, "\n\n");

                document.querySelector('.revision input[name="new-rev"]').value = newRev;
                document.querySelector('.revision input[name="parent-rev"]').value = window.tov.displayed_rev || "";
            }
            document.querySelector('.revision input[name="name"]').value = document.querySelector(".iam input#name").value;
            document.querySelector('.revision input[name="password"]').value = document.querySelector(".iam input#password").value;
            const fd = new FormData(document.querySelector(".revision form"));

            if (document.querySelector(".cap-doc ol.req-in-flight")) { return; }
            document.querySelector(".cap-doc ol").classList.toggle("req-in-flight");
            fetch(window.location.pathname + "/doc/edit", { method: "POST", body: fd }).then(
                resp => {
                    update_rev_list(resp);
                    // reset submission fields
                    document.querySelector('.revision input[name="new-rev"]').value = "";
                    document.querySelector('.revision input[name="parent-rev"]').value = "";
                    // reset editing area
                    delete window.tov.old_rev_text;
                    document.querySelector(".cap-doc article").innerHTML = "Something will show up here once you select a revision.";
                    document.querySelector(".cap-doc article").removeAttribute("contenteditable");
                    document.querySelector("[data-js-enable-doc-editing]").innerText = "Edit currently displayed revision";
                    document.querySelector(".revision textarea#comment").innerText = "";
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
            if (!window.tov.old_rev_text ||
                confirm("Displaying this revision will irretrievably discard the edits you've made so far. Proceed?")) {
                const link = event.target.getAttribute("href");
                fetchRevision(link);
                window.tov.displayed_rev = link.split("/")[link.split("/").length - 1];
                delete window.tov.old_rev_text;
                document.querySelector("[data-js-enable-doc-editing]").innerText = "Edit currently displayed revision";
            }
        });
    });

    document.querySelector("[data-js-expand-all-revs]").addEventListener("click", function (event) {
        event.preventDefault();
        for (thing of document.querySelectorAll(".cap-doc ol li details")) {
            thing.open = true;
        }
    });

    document.querySelector("[data-js-collapse-all-revs]").addEventListener("click", function (event) {
        event.preventDefault();
        for (thing of document.querySelectorAll(".cap-doc ol li details")) {
            thing.open = false;
        }
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
