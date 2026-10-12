import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from validate_distribution import inspect_ipa, inspect_resources, tracking_errors


class DistributionPrivacyTests(unittest.TestCase):
    def test_itms_91064_submission_is_rejected(self):
        self.assertTrue(tracking_errors({"NSPrivacyTracking": True, "NSPrivacyTrackingDomains": []}))
        self.assertTrue(tracking_errors({"NSPrivacyTracking": True}))

    def test_tracking_domains_require_boolean_true(self):
        for value in [False, "true", 1]:
            self.assertTrue(tracking_errors({"NSPrivacyTracking": value,
                                             "NSPrivacyTrackingDomains": ["ads.example.org"]}))

    def test_valid_tracking_and_vendor_declarations_pass(self):
        self.assertFalse(tracking_errors({"NSPrivacyTracking": True,
                                          "NSPrivacyTrackingDomains": ["ads.example.org"]}))
        self.assertFalse(tracking_errors({"NSPrivacyCollectedDataTypes": []}))
        self.assertFalse(tracking_errors({"NSPrivacyTracking": False}))

    def test_empty_optional_domains_are_rejected(self):
        self.assertTrue(tracking_errors({"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": []}))

    def test_urls_wildcards_bad_labels_and_non_strings_are_rejected(self):
        for value in ["https://ads.example.org", "ads.example.org/track", "*.example.org",
                      "ads.example.org:443", "ads..example.org", "-ads.example.org", "127.0.0.1", 1]:
            self.assertTrue(tracking_errors({"NSPrivacyTracking": True, "NSPrivacyTrackingDomains": [value]}))
        self.assertTrue(tracking_errors({"NSPrivacyTrackingDomains": "ads.example.org"}))

    def test_missing_app_manifest_is_rejected_even_with_sdk_manifest(self):
        resources = {"Frameworks/SDK.framework/PrivacyInfo.xcprivacy": plistlib.dumps({})}
        self.assertFalse(inspect_resources(resources, "PrivacyInfo.xcprivacy")["passed"])

    def test_malformed_root_is_reported(self):
        resources = {"PrivacyInfo.xcprivacy": plistlib.dumps([])}
        self.assertFalse(inspect_resources(resources, "PrivacyInfo.xcprivacy")["passed"])

    def test_actual_ipa_resources_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            ipa = Path(directory) / "test.ipa"
            for domains, expected in [([], False), (["ads.example.org"], True)]:
                with zipfile.ZipFile(ipa, "w") as archive:
                    archive.writestr("Payload/Test.app/Info.plist", plistlib.dumps({"CFBundleVersion": "2"}))
                    archive.writestr("Payload/Test.app/PrivacyInfo.xcprivacy", plistlib.dumps(
                        {"NSPrivacyTracking": True, "NSPrivacyTrackingDomains": domains}))
                    archive.writestr("Payload/Test.app/Frameworks/SDK.framework/PrivacyInfo.xcprivacy", plistlib.dumps({}))
                self.assertEqual(inspect_ipa(ipa)["passed"], expected)


if __name__ == "__main__":
    unittest.main()
