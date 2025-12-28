const fs = require('fs');
const path = require('path');

module.exports = function (context) {
    const projectRoot = context.opts.projectRoot;
    const buildJsPath = path.join(projectRoot, 'node_modules', 'cordova-ios', 'lib', 'build.js');

    console.log(`📝 Project Root: ${projectRoot}`);
    console.log(`📝 Path to build.js: ${buildJsPath}`);

    const mainAppBundleID = "com.aub.mobilebanking.phone.eg";
    const uiExtnBundleID = "com.aub.mobilebanking.phone.eg.UIExt";
    const nonuiExtnBundleID = "com.aub.mobilebanking.phone.eg.NonExt";

    const mainApp_PProfile = "2b9cdfa5-4472-49bf-9a68-7c04c76090c6";
    const uiExtn_PProfile = "94c8d471-940b-42b7-8d64-f071402c8b61";
    const nonuiExtn_PProfile = "b791a518-f133-46e9-86ae-799b54368345";

    console.log(`📝 mainAppBundleID: ${mainAppBundleID}, mainApp_PProfile: ${mainApp_PProfile}`);
    console.log(`📝 uiExtnBundleID: ${uiExtnBundleID}, uiExtn_PProfile: ${uiExtn_PProfile}`);
    console.log(`📝 nonuiExtnBundleID: ${nonuiExtnBundleID}, nonuiExtn_PProfile: ${nonuiExtn_PProfile}`);

    // Read the build.js file
    fs.readFile(buildJsPath, 'utf8', (err, buildJsContent) => {
        if (err) {
            console.error(`🪲 Error reading build.js: ${err.message}`);
            return;
        }

        console.log('📝 Successfully read build.js content.');

        // Define the new provisioningProfiles block for three targets
        const newProvisioningProfileBlock = `
            exportOptions.provisioningProfiles = {
                "${mainAppBundleID}": "${mainApp_PProfile}",
                "${uiExtnBundleID}": "${uiExtn_PProfile}",
                "${nonuiExtnBundleID}": "${nonuiExtn_PProfile}"
            };
            exportOptions.signingStyle = 'manual';`;

        // String to remove (the entire block you mentioned)
        const oldProvisioningBlock = `
            if (buildOpts.provisioningProfile && bundleIdentifier) {
                if (typeof buildOpts.provisioningProfile === 'string') {
                    exportOptions.provisioningProfiles = { [bundleIdentifier]: String(buildOpts.provisioningProfile) };
                } else {
                    events.emit('log', 'Setting multiple provisioning profiles for signing');
                    exportOptions.provisioningProfiles = buildOpts.provisioningProfile;
                }
                exportOptions.signingStyle = 'manual';
            }`;

        // Replace the old provisioning profile block with the new one
        const modifiedBuildJsContent = buildJsContent.replace(oldProvisioningBlock, newProvisioningProfileBlock);

        // Write the updated build.js back to disk
        fs.writeFile(buildJsPath, modifiedBuildJsContent, 'utf8', (err) => {
            if (err) {
                console.error(`🪲 Error writing modified build.js: ${err.message}`);
                return;
            }

            console.log('📝 Successfully updated build.js with new provisioning profiles.');
        });
    });
};


