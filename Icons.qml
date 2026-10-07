pragma Singleton

import Quickshell

// Lucide icons (ISC, see icons/LICENSE-lucide.txt) rendered as recolourable data URLs.
Singleton {
    readonly property var paths: ({
            "settings-2": '<path d="M20 7h-9"/><path d="M14 17H5"/><circle cx="17" cy="17" r="3"/><circle cx="7" cy="7" r="3"/>',
            "check": '<path d="M20 6 9 17l-5-5"/>',
            "chevron-left": '<path d="m15 18-6-6 6-6"/>',
            "chevron-right": '<path d="m9 18 6-6-6-6"/>',
            "refresh-cw": '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
            "pin": '<path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>',
            "square": '<rect width="18" height="18" x="3" y="3" rx="2"/>',
            "square-check": '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="m9 12 2 2 4-4"/>'
        })

    function url(name, colour) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="${colour}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${paths[name] ?? ""}</svg>`;
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }
}
