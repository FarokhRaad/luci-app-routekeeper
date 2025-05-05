'use strict';
'require form';
'require routekeeper.api as api';
'require ui';



let eventListenerAttached = false;

return L.view.extend({

    //---------------------------------------------------------------------------------------------------
    //-- Load Settings
    //---------------------------------------------------------------------------------------------------
    load: function() {
        return api.loadSettings()
            .then(response => response?.settings ?? {})
            .catch(() => ({}));
    },
    render: function(settings) {
        const m = new form.Map('routekeeper', _('Test Settings'), _('Modify test settings.'));

        //---------------------------------------------------------------------------------------------------
        //-- Define the options array with keys, labels, defaults, and descriptions (tooltips).
        //---------------------------------------------------------------------------------------------------
        const options = [{
                key: 'curl_address',
                label: _('Curl Address'),
                default: 'http://www.gstatic.com/generate_204',
                description: _('The URL used for Curl requests.')
            },
            {
                key: 'ping_address',
                label: _('Ping Address'),
                default: '8.8.8.8',
                description: _('The IP address used for ping tests.')
            },
            {
                key: 'curl_timeout',
                label: _('Curl Timeout'),
                default: '2',
                description: _('The maximum time to wait for a Curl response.')
            },
            {
                key: 'curl_max_time',
                label: _('Curl Max Time'),
                default: '2',
                description: _('The maximum time for the entire Curl request.')
            },
            {
                key: 'ping_count',
                label: _('Ping Count'),
                default: '1',
                description: _('Number of ping requests to send.')
            },
            {
                key: 'ping_timeout',
                label: _('Ping Timeout'),
                default: '1',
                description: _('Time to wait for each ping response.')
            }
        ];

        //---------------------------------------------------------------------------------------------------
        //-- Directly map the settings data from `options`
        //---------------------------------------------------------------------------------------------------
        const defaultMap = Object.fromEntries(options.map(opt => [opt.key, opt.default]));
        const labelMap = Object.fromEntries(options.map(opt => [opt.key, opt.label]));
        const sortedSettings = {
            ...defaultMap,
            ...settings
        };

        //---------------------------------------------------------------------------------------------------
        //-- Test_Type Section
        //---------------------------------------------------------------------------------------------------
        const testTypeSection = m.section(form.NamedSection, 'global', 'routekeeper', _('</br>'));
        testTypeSection.anonymous = true;

        const testTypeField = testTypeSection.option(form.ListValue, 'test_type', _('Test Type'), _('Select a Health Check'));
        testTypeField.value('both', _('Ping & Curl'));
        testTypeField.value('ping', _('Ping Only'));
        testTypeField.value('curl', _('Curl Only'));

        testTypeField.cfgvalue = function(section_id) {
            return settings?.test_type || 'both';
        };

        testTypeField.onchange = function(event, section_id, newValue) {
            if (!newValue || !['both', 'ping', 'curl'].includes(newValue)) {
                return;
            }

            const updatedSettings = {
                settings: {
                    test_type: newValue
                }
            };

            api.saveSettings(updatedSettings)
                .then(response => {
                    if (response?.success) {
                        settings.test_type = newValue;
                        const banner = ui.addNotification(null, _(`Successfully updated Test Type to '${newValue}'.`), 'info');
                        setTimeout(() => banner?.remove(), 2000);
                    }
                })
                .catch(() => {
                    ui.addNotification(null, _('API error updating Test Type.'), 'error');
                });
        };

        //---------------------------------------------------------------------------------------------------
        //-- Define a TableSection for Options
        //---------------------------------------------------------------------------------------------------
        const s = m.section(form.TableSection, 'global');
        s.anonymous = true;
        s.addremove = false;
        s.cfgsections = function() {
            return options.map(opt => opt.key);
        };

        //---------------------------------------------------------------------------------------------------
        //-- Column: Setting Name
        //---------------------------------------------------------------------------------------------------
        const nameColumn = s.option(form.DummyValue, 'setting_name', _('Setting'));
        nameColumn.width = "20%";
        nameColumn.cfgvalue = function(section_id) {
            return `${labelMap[section_id] || section_id}`;
        };
        nameColumn.rawhtml = true; // Ensure HTML rendering


        //---------------------------------------------------------------------------------------------------
        //-- Column: Input Fields
        //---------------------------------------------------------------------------------------------------
        const valueField = s.option(form.DummyValue, 'value', _('Value'));
        valueField.width = "511px";
        valueField.rawhtml = true; // Allows HTML content inside

        valueField.cfgvalue = function(section_id) {
            const currentValue = sortedSettings?.[section_id];
            const defaultValue = defaultMap[section_id];
            const displayValue = currentValue === undefined || currentValue === defaultValue ? '' : String(currentValue);

            // Find the matching description
            const option = options.find(opt => opt.key === section_id);
            const description = option?.description ?
                `<div class="cbi-value-description">${option.description}</div>` :
                '';

            return `
        <input type="text" class="cbi-input-text" 
               name="${section_id}" 
               value="${displayValue}" 
               placeholder="${defaultValue}" 
               style="width: 100%;">
        ${description}`;
        };


        // Manually set placeholders after form loads
        setTimeout(() => {
            document.querySelectorAll("input.cbi-input-text").forEach(inputField => {
                const sectionId = inputField.closest("tr")?.getAttribute("data-section-id");
                if (sectionId && defaultMap[sectionId]) {
                    inputField.setAttribute("placeholder", defaultMap[sectionId]);
                }
            });
        }, 80);



        //---------------------------------------------------------------------------------------------------
        //-- Column: Save Button
        //---------------------------------------------------------------------------------------------------
        const saveButton = s.option(form.DummyValue, 'save_button', _('Save'));
        saveButton.rawhtml = true;
        saveButton.cfgvalue = function(section_id) {
            return E("button", {
                class: "cbi-button cbi-button-positive routekeeper-save-btn",
                "data-section": section_id,
                type: "button"
            }, _("Save"));
        };


        //---------------------------------------------------------------------------------------------------
        //-- Attach Global Event Listener
        //---------------------------------------------------------------------------------------------------
        if (!eventListenerAttached) {
            document.addEventListener("click", function(event) {
                if (!event.target.classList.contains("routekeeper-save-btn")) return;

                const section_id = event.target.getAttribute("data-section");
                const row = event.target.closest("tr");

                let inputField = row.querySelector("input.cbi-input-text");
                let newValue = inputField ? inputField.value.trim() : "";

                const defaultValue = defaultMap[section_id] || "";
                const currentValue = sortedSettings?.[section_id] ?? defaultValue;

                if (newValue === currentValue || (newValue === "" && currentValue === defaultValue)) {
                    return; // No change, exit function
                }

                const updatedSettings = {
                    settings: {
                        [section_id]: newValue || defaultValue
                    }
                };

                api.saveSettings(updatedSettings)
                    .then(response => {
                        if (response?.success) {
                            sortedSettings[section_id] = newValue || defaultValue;
                            inputField.value = newValue || "";
                            inputField.setAttribute("placeholder", defaultValue);

                            const displayedNewValue = newValue === "" ? "Default" : newValue;
                            const displayedOldValue = currentValue === "" ? "Default" : currentValue;

                            // Show notification
                            const successBanner = ui.addNotification(
                                null,
                                _(`Successfully updated '${labelMap[section_id] || section_id}' from '${displayedOldValue}' to '${displayedNewValue}'.`),
                                "info"
                            );

                            // Remove notification after 2 seconds
                            setTimeout(() => successBanner?.remove(), 2000);
                        }
                    })
                    .catch(() => {
                        ui.addNotification(null, _(`API error updating '${labelMap[section_id] || section_id}'.`), "error");
                    });
            });

            eventListenerAttached = true;
        }

        return m.render();
    }
});