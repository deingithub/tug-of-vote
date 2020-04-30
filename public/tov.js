document.addEventListener("DOMContentLoaded", function () {
    const dangerousThings = document.querySelectorAll("[data-js-confirm]");
    for (thing of dangerousThings) {
        thing.addEventListener("click", function (event) {
            if (!window.confirm(event.target.getAttribute("data-js-confirm"))) {
                event.preventDefault();
            }
        });
    }

    if (document.querySelector("[data-js-countdown-to]")) {
        updateCountdown();
    }
    if (document.querySelector("section[class$=results]")) {
        window.setTimeout(fetchUpdates, 5000);
    }
});

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

function fetchUpdates() {
    fetch(window.location)
        .then(response => response.text())
        .then(text => {
            const div = document.createElement("section");
            div.innerHTML = text;
            // preserve countdown
            div.querySelector(".object-metadata [data-js-countdown-to]").outerHTML = document.querySelector(".object-metadata [data-js-countdown-to]").outerHTML;
            document.querySelector("section[class$=results]").outerHTML = div.querySelector("section[class$=results]").outerHTML;
            window.setTimeout(fetchUpdates, 5000);
        });
}