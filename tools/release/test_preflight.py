import unittest
from preflight import checks, valid_https


class ReleaseGatesTests(unittest.TestCase):
    def setUp(self):
        # Synthetic IDs only; these are never submitted or written to app resources.
        self.config = {'productID': 'jp.test.exammaster.unlock', 'privacyPolicyURL': 'https://support.test/privacy',
                       'contentCredit': '出典表示', 'ads': {'adMobAppID': 'ca-app-pub-1234567890123456~1234567890',
                       'bannerAdUnitID': 'ca-app-pub-1234567890123456/1234567890',
                       'interstitialAdUnitID': 'ca-app-pub-1234567890123456/1234567891'}}
        self.product = {'productID': self.config['productID'], 'type': 'NonConsumable'}
        self.info = {'GADApplicationIdentifier': self.config['ads']['adMobAppID'], 'NSUserTrackingUsageDescription': '広告の説明'}
        self.settings = {'PRODUCT_BUNDLE_IDENTIFIER': 'jp.test.exammaster', 'DEVELOPMENT_TEAM': 'ABCDEFGHIJ',
                         'MARKETING_VERSION': '1.0', 'CURRENT_PROJECT_VERSION': '2', 'SDK_VERSION': '27.0', 'PLATFORM_NAME': 'iphoneos'}
        self.bank = {'isDraft': False}

    def run_checks(self, **overrides):
        values = dict(config=self.config, bank=self.bank, product=self.product, info=self.info,
                      settings=self.settings, policy='正式な運営者のプライバシーポリシー')
        values.update(overrides)
        return {item['id']: item['passed'] for item in checks(**values)}

    def test_complete_static_configuration_passes(self):
        self.assertTrue(all(self.run_checks().values()))

    def test_sample_ids_and_missing_team_are_rejected(self):
        self.settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'jp.example.exammaster.networkspecialist'
        self.settings['DEVELOPMENT_TEAM'] = ''
        self.assertFalse(self.run_checks()['bundle'])
        self.assertFalse(self.run_checks()['team'])

    def test_draft_cannot_be_archived(self):
        self.assertFalse(self.run_checks(bank={'isDraft': True})['draft'])
        self.assertFalse(self.run_checks(bank={})['draft'])

    def test_mismatched_or_consumable_product_is_rejected(self):
        self.product['productID'] += '.other'
        self.assertFalse(self.run_checks()['iap'])
        self.product.update(productID=self.config['productID'], type='Consumable')
        self.assertFalse(self.run_checks()['iap'])

    def test_sample_or_mismatched_ad_app_is_rejected(self):
        self.info['GADApplicationIdentifier'] = 'ca-app-pub-1234567890123456~0000000000'
        self.assertFalse(self.run_checks()['ad_app'])
        self.config['ads']['adMobAppID'] = 'ca-app-pub-3940256099942544~1458002511'
        self.info['GADApplicationIdentifier'] = self.config['ads']['adMobAppID']
        self.assertFalse(self.run_checks()['ad_app'])

    def test_enabled_sample_units_are_rejected_but_disabled_units_are_not_required(self):
        self.config['ads']['bannerAdUnitID'] = 'ca-app-pub-3940256099942544/2934735716'
        self.assertFalse(self.run_checks()['ad_banner'])
        self.config['ads']['bannerEnabled'] = False
        self.assertTrue(self.run_checks()['ad_banner'])

    def test_example_and_non_https_urls_are_rejected(self):
        for url in [None, '', 'http://support.test/privacy', 'https://example.com/privacy',
                    'https://a.example.org', 'https://localhost', 'https://user:pass@support.test']:
            self.assertFalse(valid_https(url))
        self.assertTrue(valid_https('https://support.test/privacy'))

    def test_development_policy_and_old_sdk_are_rejected(self):
        self.assertFalse(self.run_checks(policy='この文章は開発用サンプルです')['policy_text'])
        self.settings['SDK_VERSION'] = '25.4'
        self.assertFalse(self.run_checks()['sdk'])

    def test_simulator_or_mac_sdk_does_not_count_as_distribution_sdk(self):
        self.settings['PLATFORM_NAME'] = 'iphonesimulator'
        self.assertFalse(self.run_checks()['sdk'])
        self.settings['PLATFORM_NAME'] = 'macosx'
        self.assertFalse(self.run_checks()['sdk'])


if __name__ == '__main__':
    unittest.main()
