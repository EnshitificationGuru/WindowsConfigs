// ==UserScript==
// @name         Brave.com Usage Metrics + Cookie Opt-Out
// @namespace    https://github.com/
// @version      1.1
// @description  Automatically sets app.usageMetricsOptOut to "true" on any *.brave.com page AND sets the useLocation=0 cookie on search.brave.com
// @author       Enshitification Guru/TrustedExpert
// @match        https://*.brave.com/*
// @match        http://*.brave.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function () {
    'use strict';

    try {
        // === LocalStorage opt-out (original functionality) ===
        if (localStorage.getItem('app.usageMetricsOptOut') !== 'true') {
            localStorage.setItem('app.usageMetricsOptOut', 'true');
            console.log('%c[Brave Opt-Out Userscript] Set app.usageMetricsOptOut = true', 'color: #ff0000; font-weight: bold;');
        }

        // === Cookie opt-out for search.brave.com only ===
        if (window.location.hostname === 'search.brave.com') {
            // Check current cookie value
            const cookies = document.cookie.split('; ');
            const useLocationCookie = cookies.find(row => row.startsWith('useLocation='));
            const currentValue = useLocationCookie ? useLocationCookie.split('=')[1] : null;

            if (currentValue !== '0') {
                // Build cookie string (persistent for 1 year, secure on HTTPS)
                let cookieStr = 'useLocation=0; domain=search.brave.com; path=/; max-age=31536000; SameSite=Lax';
                if (window.location.protocol === 'https:') {
                    cookieStr += '; Secure';
                }
                document.cookie = cookieStr;

                console.log('%c[Brave Opt-Out Userscript] Set useLocation=0 cookie on search.brave.com', 'color: #ff0000; font-weight: bold;');
            }
        }
    } catch (e) {
        console.warn('[Brave Opt-Out Userscript] Could not set opt-out (localStorage or cookie):', e);
    }
})();