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

// Determine the operating system
let userAgent = navigator.userAgent.toLowerCase();
let osType = userAgent.includes("mac") ? "mac" : userAgent.includes("win") ? "windows" : "mac";
const getOS = (...choices) => choices[["mac", "windows"].indexOf(osType)];

// Array of content to be displayed at each step
const stepContent = [
    () => `<b>To get started, you'll need:</b><ul class="list-disc list-inside"><li>${getOS(
        "A Mac running macOS 10.15 or later",
        "A PC running Windows 10 or later"
    )}</li><li>An iCloud account (a burner account is recommended but not required)</li><li>An Internet connection</li><li>An iPhone with iOS 16 or later</li></ul><br>On your computer, download the following:<a class="btn-fill" target="_blank" href="${getOS(
        "https://cdn.altstore.io/file/altstore/altserver.zip",
        "https://cdn.altstore.io/file/altstore/altinstaller.zip"
    )}">Download AltServer</a>\n<a class="btn-fill" target="_blank" href="${getOS(
        "https://github.com/atpugvaraa/cisum/releases/latest/download/cisum.ipa",
        "https://github.com/atpugvaraa/cisum/releases/latest/download/cisum.ipa"
    )}">Download cisum.ipa</a>\n${getOS(
        'Then, open the downloaded AltServer zip file and extract it. Then drag <code>AltServer.app</code> to your Applications folder. Now, open the app (you may have to right click and select "Open" if you get a warning).',
        'Then, extract the downloaded AltInstaller zip file and run <code>setup.exe</code> to install AltServer. You\'ll also need to install the non-Microsoft Store version of iTunes and iCloud, and uninstall the Microsoft Store versions if you have either installed.<div class="flex flex-wrap gap-2"><a class="btn-fill" href="https://support.apple.com/en-us/HT210384">Download iTunes</a><a class="btn-fill" href="https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe">Download iCloud</a></div>'
    )}`,
    () => `<b>Follow these steps to install SideStore:</b><ul class="list-disc list-inside"><li>Plug your device into your computer via a cable</li><li>Trust your computer on your device (if prompted)</li><li>${getOS(
        "Launch AltServer and hold options and pick <code>Sideload .ipa</code> from the AltServer icon in the menu bar",
        "Shift-Right click on the AltServer tray icon, and pick <code>Sideload .ipa</code>"
    )}</li><li>Select the SideStore ipa and follow the instructions until AltServer confirms that SideStore has been installed (you may need to enter your iCloud account login details)</li><li>If you are running iOS or iPadOS 16 or higher, you must enable Developer Mode to use sideloaded apps (this only shows up <b>after you sideload an app for the first time</b>)<ul class="list-decimal list-inside ml-4 sm:ml-6"><li>Open Settings</li><li>Tap "Privacy & Security"</li><li>Scroll to the bottom, and toggle Developer Mode on</li></ul></li><li>Open <code>Settings > General > VPN & Device Management</code> on your device and approve the <code>Developer App</code> with your Apple ID's email.`,
    () => `<b>Follow these steps to Pair your device:</b><ul class="list-disc list-inside"><li>Extract <code>Jitterbugpair.zip</code> and make sure your device is still connected to the computer.</li>${getOS(
        "<li>Open your device to its home screen. Once done, execute <code>JitterBugPair</code> via double-click or right-click and open.</li><li>After that, in your home directory, you will have a file that ends with <code>.mobiledevicepairing</code>.</li><li>Transfer the <code>.mobiledevicepairing</code> file to your device using Airdrop or other methods (avoid using email and some cloud services as they can mess up the file).</li>",
        "<li>Open your device to its home screen. Once done, go into File Explorer and navigate to the folder where <code>jitterbugpair.exe</code> is located.</li><li>In the Navigation/Address bar where the folder location is, click an empty spot and type 'powershell' and press Enter.</li><li>It should open a blue-colored window called PowerShell. From there, type <code>./jitterbugpair.exe</code> in the PowerShell window and press Enter.</li><li>After that, in File Explorer, you will have a file that ends with <code>.mobiledevicepairing</code>.</li><li>Transfer the <code>.mobiledevicepairing</code> file to your device using iTunes (using iTunes file sharing when connecting to your device) or other methods (avoid using email and some cloud services as they can mess up the file).</li>"
    )}</ul><br><br>Launch SideStore, select OK when it asks for the pairing file. Find where you stored the <code>.mobiledevicepairing</code> file and select it to pair your device!`,
    () => `On your device, you'll need to download the WireGuard VPN app.<a class="btn-fill" target="_blank" href="https://apps.apple.com/us/app/wireguard/id1441195209">Download WireGuard</a>After that, you'll need to import SideStore's WireGuard configuration. (Download the file and then you can "share" it to the WireGuard app).<a class="btn-fill" target="_blank" href="https://github.com/SideStore/SideStore/releases/download/0.1.1/SideStore.conf">Download WireGuard Config</a>You'll have to turn on the VPN every time you want to use SideStore to sideload apps. You can turn it off when you're done, and the VPN doesn't connect to an external server, as it operates On-Device.<br><br>SideStore can use the On-Device VPN in the background for auto-refresh if you use your device enough for it to refresh when unlocked.`,
    () => `Now to finish the process: <ul class="list-disc list-inside"><li>Open SideStore and sign in with the same Apple ID you used to install SideStore.</li><li>Go to the Apps tab and refresh the SideStore app itself once (you might have to swipe up to your homescreen for the process to complete).</li></ul><br> Now, you're all set! You can install apps from the sources tab or any other <code>.ipa</code> file you have.<br>If you run into any more issues, you can get support in our <a class="glink" target="_blank" href="https://discord.gg/RgpFBX3Q3k">Discord server.</a> <br><br>Note: We had to remove SideServer instructions as it was causing issues with the SideStore install.`,
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
