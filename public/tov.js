document.addEventListener("DOMContentLoaded", function () {
    dangerousThings = document.querySelectorAll("[data-js-confirm]");
    for (thing of dangerousThings) {
        thing.addEventListener("click", function (event) {
            if (!window.confirm(thing.getAttribute("data-js-confirm"))) {
                event.preventDefault();
            }
        });
    }
});