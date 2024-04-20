// Function to define a property with get and set methods
function defineProperty(obj, prop, getter, setter) {
    Object.defineProperty(obj, prop, {
        get: getter,
        set: setter,
        enumerable: true,
        configurable: true,
    });
}

// Utility function to handle default module export
function getDefaultExport(module) {
    return module && module.__esModule ? module.default : module;
}

// Constants for querying DOM elements and setting up the IntersectionObserver
const querySelector = document.querySelector.bind(document);
const querySelectorAll = document.querySelectorAll.bind(document);
const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
        if (entry.isIntersecting) {
            entry.target.classList.add("animate-fade-show");
        } else {
            entry.target.classList.remove("animate-fade-show");
        }
    });
});
const fadeElements = querySelectorAll(".section-fade, .section-fade-items");
fadeElements.forEach((element) => observer.observe(element));

// Array of content to be displayed at each step
const stepContent = [
    () => `<b>To get started, you'll need:</b><ul class="list-disc list-inside"><li>An Internet connection</li><li>An iPhone with iOS 16 or later</li><li>A method to sideload/install the app</li></ul><br>On your device, download the following: \n
    <a class="btn-fill" target="_blank" href="
        "https://github.com/atpugvaraa/cisum/releases/latest/download/cisum.ipa"
        ">Download cisum.ipa</a>\n
        <br><br> Note: Sideloading methods include: <ul class="list-disc list-inside"><li>Altstore</li><li>Sideloadly</li><li>TrollStore</li><li>ESign</li></ul>`,
    () => `<b>Using your preferred method to install cisum:</b><ul class="list-disc list-inside">
    Official Download:
    <br>
    <a class="btn-fill" target="_blank" href=" "" ">Download from AppStore</a>
    <br>
    <li>You can use TrollStore on a supported device.</li>
    <li>Sideloady/AltStore/SideStore if you are fine with 7-day signing.</li>
    <li>You can use ESign with a certificate.</li>
    <br>Sideload <code>cisum.ipa</code> using any of the above methods on you iOS 16.0 and later device for the best experience.
    <br><br><br><br><br><br>
    Note: You might be able to install it via TestFlight or from the AppStore if I ever get an Apple Developer Account.`,
    () => `<b>This is all that is needed to enjoy you favourite songs!</b>
    <br><br>
    Launch cisum, create an account and get started with jamming out to your favourite tunes!
    <br><br>
    Now you can to listen to all of the songs that you want and that too for absolutely free!
    <br>
    Alongside <b>NO ADS</b> during playback at all!
    <br><br><br><br><br><br>
    Note: This app shall be obtained only from my <b><a href="https://github.com/atpugvaraa/cisum">Github</a></b> or from the AppStore. (Published by me)
    <br>
    This app shall be obtained for free. Do not buy if anyone ever tries to sell this app. Please report them.
    `,
];

// Get references to the relevant DOM elements
const osSelect = querySelector("#setup-os-select");
const nextButton = querySelector("#setup-next-btn");
const prevButton = querySelector("#setup-prev-btn");
const content = querySelector("#setup-content");
const stepperItems = Array.from(querySelectorAll('#setup-stepper li:not([aria-hidden="true"])'));

// Function to control step transitions and button visibility
const changeStep = (stepIndex) => {
    // Toggle active class for the step indicators
    stepperItems.forEach((item, index) => {
        item.classList.toggle("active", index === stepIndex);
    });

    // Animate content transition
    content.classList.add("!opacity-0", "translate-y-[10px]");
    setTimeout(() => {
        content.innerHTML = stepContent[stepIndex]();
        content.classList.remove("!opacity-0", "translate-y-[10px]");
    }, 300);

    // Control button visibility
    prevButton.classList.toggle("hidden", stepIndex < 1);
    nextButton.classList.toggle("hidden", stepIndex > 1);

    // Additional styling adjustments for button wrapper at step 2
    querySelector("#setup-btn-wrap").classList.toggle("onlyprev", stepIndex === 2);
};

// Event listeners for previous and next buttons
nextButton.addEventListener("click", () => {
    const currentIndex = stepperItems.findIndex((item) => item.classList.contains("active"));
    changeStep(currentIndex + 1);
});

prevButton.addEventListener("click", () => {
    const currentIndex = stepperItems.findIndex((item) => item.classList.contains("active"));
    changeStep(currentIndex - 1);
});

// Initial step setup
changeStep(0);
