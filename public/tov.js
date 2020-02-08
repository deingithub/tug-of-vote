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
        elem.innerHTML = `Voting ends in ${hours} hour${hours == 1 ? '' : 's'} and ${mins} minute${mins == 1 ? '' : 's'}.`;
        window.setTimeout(updateCountdown, 5000);
    }
}