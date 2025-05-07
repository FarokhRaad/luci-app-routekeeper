'use strict';

'require form';
'require ui';
'require routekeeper.api as api';

return L.Class.extend({

    //-----------------------------------------------------------------------------------------------------------
    //-- Asynchronous CSS Loading Without Blocking UI Rendering
    //-----------------------------------------------------------------------------------------------------------
    loadCSS: function (cssFile) {
        if (!document.querySelector(`link[href="${cssFile}"]`)) {
            let link = document.createElement("link");
            link.rel = "stylesheet";
            link.href = cssFile;
            document.head.appendChild(link);
        }
    },

    //-----------------------------------------------------------------------------------------------------------
    //-- Create a configuration form to manage network interfaces and test connectivity
    //-----------------------------------------------------------------------------------------------------------
    createRouteKeeperTable: function (interfaces, defaultGateway) {
        let self = this;

        // ? Load CSS asynchronously (without making this function async)
        self.loadCSS('/luci-static/resources/routekeeper/routekeeper.css');

        // ? Continue loading the table UI normally
        self.interfaceMap = new Map(interfaces.map(iface => [iface.replace(/[^a-zA-Z0-9]/g, "_"), iface]));
        self.getInterfaceBySectionId = function (section_id) {
            return self.interfaceMap.get(section_id) || section_id;
        };

        // Cache test buttons and "Make Default" buttons
        self.testButtons = [];
        self.makeDefaultButtons = [];

        setTimeout(() => {
            self.testButtons = [...document.querySelectorAll('.cbi-button-action')];
            self.makeDefaultButtons = [...document.querySelectorAll('.cbi-button-primary, .cbi-button-positive')];
        }, 500);

        let m = new form.Map('routekeeper', _('RouteKeeper'), _('Manage network interfaces and test connectivity.'));
        let s = m.section(form.TableSection, 'interface', _('<br/>'));
        s.anonymous = true;
        s.addremove = false;
        s.rowcolors = true;

        //-----------------------------------------------------------------------------------------------------------
        //-- Define how section IDs should be mapped from interface names
        //-----------------------------------------------------------------------------------------------------------
        s.cfgsections = () => interfaces.map(iface => self.getInterfaceBySectionId(iface));

        //-----------------------------------------------------------------------------------------------------------
        //-- Display Interface Name
        //-----------------------------------------------------------------------------------------------------------
        s.option(form.DummyValue, 'iface', _('Interface Name')).cfgvalue = section_id =>
            self.getInterfaceBySectionId(section_id) || section_id;

        //-----------------------------------------------------------------------------------------------------------
        //-- Add a "Test" button for each interface
        //-----------------------------------------------------------------------------------------------------------
        s.option(form.DummyValue, 'test', _('Test')).cfgvalue = section_id => {
            let button = E("button", {
                class: "cbi-button cbi-button-action",
                "data-iface": section_id
            }, _("Test"));
            return button;
        };

        //-----------------------------------------------------------------------------------------------------------
        //-- Display test results for "curl" and "ping"
        //-----------------------------------------------------------------------------------------------------------
        ['curl', 'ping'].forEach(type => {
            s.option(form.DummyValue, `${type}_result`, _(type.charAt(0).toUpperCase() + type.slice(1) + ' Result')).cfgvalue = section_id =>
                E("span", {
                    id: `${type}-${section_id}`
                }, E("span", {
                    style: "margin: 30px;"
                }, "-"))
        });

        //-----------------------------------------------------------------------------------------------------------
        //-- Add "Make Default" button
        //-----------------------------------------------------------------------------------------------------------
        s.option(form.DummyValue, 'default', _('Default Gateway')).cfgvalue = section_id => {
            let iface = self.getInterfaceBySectionId(section_id);
            let isDefault = iface === defaultGateway;
            let button = E("button", {
                class: isDefault ? "cbi-button cbi-button-primary" : "cbi-button cbi-button-positive",
                "data-iface": section_id,
                disabled: isDefault ? "disabled" : null
            }, isDefault ? "Default" : "Make Default");

            return button;
        };

        //-----------------------------------------------------------------------------------------------------------
        //-- Set the default gateway for the network
        //-----------------------------------------------------------------------------------------------------------
        async function setDefaultGateway(section_id) {
            let iface = self.getInterfaceBySectionId(section_id);
            if (!iface) return;

            let button = document.querySelector(`button[data-iface="${section_id}"]`);
            if (!button || button.disabled) return;  // Prevent multiple clicks

            button.disabled = true;  // Disable button immediately

            let result = await api.setDefaultGateway(iface);
            if (result === true || result?.success) {
                defaultGateway = iface;

                // ? Ensure only default gateway buttons are updated
                document.querySelectorAll('.cbi-button-positive, .cbi-button-primary').forEach(btn => {
                    let btnIface = btn.getAttribute("data-iface");
                    if (btnIface) {  // Ensure we're targeting "Make Default" buttons, not save buttons
                        btn.innerText = btnIface === section_id ? "Default" : "Make Default";
                        btn.disabled = btnIface === section_id;
                        btn.classList.remove("cbi-button-positive", "cbi-button-primary");
                        btn.classList.add(btnIface === section_id ? "cbi-button-primary" : "cbi-button-positive");
                    }
                });
            }

            button.disabled = false;  // Re-enable after setting default
        }

        //-----------------------------------------------------------------------------------------------------------
        //-- Function: Update Test Results
        //-----------------------------------------------------------------------------------------------------------
        function updateTestResult(type, iface, result) {
            let cell = document.getElementById(`${type}-${iface}`);
            if (cell) {
                cell.innerHTML = result
                    ? `<span style="color: #00a66c;">&#10004; ${result}</span>`
                    : `<span style="color: #d15653;">&#10008; Failed</span>`;
            }
        }

        //-----------------------------------------------------------------------------------------------------------
        //-- Function: Clear Test Results
        //-----------------------------------------------------------------------------------------------------------
        function clearTestResults() {
            interfaces.forEach(iface => {
                let cellCurl = document.getElementById(`curl-${iface}`);
                let cellPing = document.getElementById(`ping-${iface}`);
                if (cellCurl) cellCurl.innerHTML = '<span style="margin: 30px;">-</span>';
                if (cellPing) cellPing.innerHTML = '<span style="margin: 30px;">-</span>';
            });
        }

        //-----------------------------------------------------------------------------------------------------------
        //-- Function: Load settings
        //-----------------------------------------------------------------------------------------------------------
        async function loadSettings() {
            return await api.loadSettings();  // ? Always fetch fresh settings
        }
        //-----------------------------------------------------------------------------------------------------------
        //-- Function: Run test for a specific interface
        //-----------------------------------------------------------------------------------------------------------
        async function testInterface(section_id) {
            clearTestResults();

            let iface = self.getInterfaceBySectionId(section_id);
            if (!iface) return;

            // Disable ALL test and "Make Default" buttons temporarily
            self.testButtons.forEach(btn => btn.disabled = true);
            self.makeDefaultButtons.forEach(btn => btn.disabled = true);

            let settings = await loadSettings();
            let testType = settings?.settings?.test_type ?? settings?.test_type;
            testType = ["ping", "curl", "both"].includes(testType?.trim().toLowerCase()) ? testType : "both";

            let pingCell = document.getElementById(`ping-${section_id}`);
            let curlCell = document.getElementById(`curl-${section_id}`);

            if (pingCell && (testType === "both" || testType === "ping")) {
                pingCell.innerHTML = `<span class='loading-icon' style='margin-left: 28px; color: #4da1c0;'>&#9696;</span>`;
            }

            if (curlCell && (testType === "both" || testType === "curl")) {
                curlCell.innerHTML = `<span class='loading-icon' style='margin-left: 28px; color: #4da1c0;'>&#9696;</span>`;
            }

            // Run tests and **wait** for them to complete
            let pingPromise = (testType === "both" || testType === "ping") ? api.runPingTest(iface).then(pingResult => {
                updateTestResult('ping', section_id, pingResult?.ping_result);
            }).catch(() => {
                updateTestResult('ping', section_id, null);
            }) : Promise.resolve();

            let curlPromise = (testType === "both" || testType === "curl") ? api.runCurlTest(iface).then(curlResult => {
                updateTestResult('curl', section_id, curlResult?.curl_result);
            }).catch(() => {
                updateTestResult('curl', section_id, null);
            }) : Promise.resolve();

            // Ensure that buttons are only enabled **after** both tests finish
            await Promise.all([pingPromise, curlPromise]);

            // Re-enable buttons after all tests are completed
            self.testButtons.forEach(btn => btn.disabled = false);
            self.makeDefaultButtons.forEach(btn => {
                let isDefault = btn.innerText.trim() === "Default";
                btn.disabled = isDefault;
            });
        }


        //-----------------------------------------------------------------------------------------------------------
        //-- Create a TableSection for the "Test All Interfaces" Button
        //-----------------------------------------------------------------------------------------------------------
        let testAllSection = m.section(form.TableSection, 'test_all_section', _(''));
        testAllSection.anonymous = true;
        testAllSection.addremove = false;

        // Ensure only one row exists
        testAllSection.cfgsections = function () {
            return ["test_all_entry"];
        };

        // Placeholder column for alignment with the interface table
        testAllSection.option(form.DummyValue, 'placeholder', _('')).cfgvalue = () => 'Test All Interfaces';


        // "Test All" button column
        testAllSection.option(form.DummyValue, 'test_all_button', _('')).cfgvalue = () => {
            let button = E("button", {
                class: "cbi-button cbi-button-action test-all",
                style: "margin-right: 335px;"
            }, _("Test"));

            return button;
        };

        //-----------------------------------------------------------------------------------------------------------
        //-- Function to Test All Interfaces
        //-----------------------------------------------------------------------------------------------------------
        async function testAllInterfaces() {
            // Disable buttons during test run
            self.testButtons.forEach(btn => btn.disabled = true);
            self.makeDefaultButtons.forEach(btn => btn.disabled = true);

            // Load test settings
            let settings = await loadSettings();
            let testType = settings?.settings?.test_type ?? settings?.test_type;
            testType = ["ping", "curl", "both"].includes(testType?.trim().toLowerCase()) ? testType : "both";

            // Show loading spinners
            interfaces.forEach(iface => {
                if (testType === "ping" || testType === "both") {
                    let pingCell = document.getElementById(`ping-${iface}`);
                    if (pingCell) {
                        pingCell.innerHTML = `<span class='loading-icon' style='margin-left: 28px; color: #4da1c0;'>&#9696;</span>`;
                    }
                }
                if (testType === "curl" || testType === "both") {
                    let curlCell = document.getElementById(`curl-${iface}`);
                    if (curlCell) {
                        curlCell.innerHTML = `<span class='loading-icon' style='margin-left: 28px; color: #4da1c0;'>&#9696;</span>`;
                    }
                }
            });

            let pingResults = [], curlResults = [];

            // Conditionally run only selected test type(s)
            if (testType === "ping" || testType === "both") {
                const pingResp = await api.runPingTestAll().catch(() => null);
                pingResults = Array.isArray(pingResp?.results) ? pingResp.results : [];
            }

            if (testType === "curl" || testType === "both") {
                const curlResp = await api.runCurlTestAll().catch(() => null);
                curlResults = Array.isArray(curlResp?.results) ? curlResp.results : [];
            }

            // Apply results
            pingResults.forEach(result => {
                updateTestResult("ping", result.interface, result.success ? result.ping_result : null);
            });

            curlResults.forEach(result => {
                updateTestResult("curl", result.interface, result.success ? result.curl_result : null);
            });

            // Re-enable buttons
            self.testButtons.forEach(btn => btn.disabled = false);
            self.makeDefaultButtons.forEach(btn => {
                let isDefault = btn.innerText.trim() === "Default";
                btn.disabled = isDefault;
            });
        }

        //-----------------------------------------------------------------------------------------------------------
        //-- Event Handlers for Buttons
        //-----------------------------------------------------------------------------------------------------------
        document.addEventListener("click", function (event) {
            if (event.target.closest(".cbi-button-action")) {
                let section_id = event.target.closest(".cbi-button-action").getAttribute("data-iface");
                testInterface(section_id);
            }
            if (event.target.closest(".cbi-button-primary, .cbi-button-positive")) {
                let section_id = event.target.closest(".cbi-button-primary, .cbi-button-positive").getAttribute("data-iface");
                if (!event.target.disabled) {
                    setDefaultGateway(section_id);
                }
            }
            if (event.target.closest(".test-all")) {
                testAllInterfaces();
            }
        });

        //-----------------------------------------------------------------------------------------------------------
        //-- Ensure functions are globally available
        //-----------------------------------------------------------------------------------------------------------
        window.testInterface = testInterface;
        window.setDefaultGateway = setDefaultGateway;
        window.testAllInterfaces = testAllInterfaces;

        return m;
    }
});
