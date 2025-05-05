'use strict';

'require view';
'require routekeeper.api as api';
'require routekeeper.table as table';  // Existing table section
'require routekeeper.test_settings as testSettings'; // Import test settings

return view.extend({
    load: function () {
        return Promise.all([
            L.resolveDefault(api.getInterfaces(), []),
            L.resolveDefault(api.getDefaultGateway(), ""),
            L.resolveDefault(api.loadSettings(), {}) // ? Use `loadSettings()` instead
        ]).then(([interfaces, defaultGateway, settings]) => {
            return { interfaces, defaultGateway, settings };
        }).catch(err => {
            console.error("[Index.js] Error fetching data:", err);
            return { interfaces: [], defaultGateway: "", settings: {} };
        });
    },

    render: function (data) {
        try {
            let formMap = table.createRouteKeeperTable(data.interfaces, data.defaultGateway); // Render table.js
            let settingsForm = testSettings.render(data.settings); // Render test_settings.js below table.js

            return Promise.all([formMap.render(), settingsForm]).then((views) => {
                return E("div", {}, views); // Wrap both sections in a div
            });
        } catch (err) {
            console.error("[Index.js] Error rendering:", err);
            return E("div", {}, "Error loading components.");
        }
    }
});
