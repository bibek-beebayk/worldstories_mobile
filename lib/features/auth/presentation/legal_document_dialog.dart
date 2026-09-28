import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/app_theme.dart';

enum LegalDocument { terms, privacy }

extension on LegalDocument {
  String get title => switch (this) {
    LegalDocument.terms => 'Terms of Service',
    LegalDocument.privacy => 'Privacy Policy',
  };

  String get updated => switch (this) {
    LegalDocument.terms => 'July 30, 2026',
    LegalDocument.privacy => 'September 19, 2026',
  };

  String get content => switch (this) {
    LegalDocument.terms => _termsHtml,
    LegalDocument.privacy => _privacyHtml,
  };
}

Future<void> showLegalDocumentDialog(
  BuildContext context,
  LegalDocument document,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: Column(
        children: [
          Container(
            color: AppTheme.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last updated: ${document.updated}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Html(data: document.content),
            ),
          ),
        ],
      ),
    ),
  ),
);

const _termsHtml = r'''
<p>These Terms of Service ("Terms") govern your access to and use of worldstories.net (the "Site"), operated by WorldStories ("we", "us", or "our"). By creating an account or using the Site, you agree to these Terms. If you do not agree, please do not use the Site.</p>

<h2>1. Your Account</h2>
<p>You are responsible for maintaining the confidentiality of your login credentials and for all activity under your account. Notify us promptly at worldstoriesnet@gmail.com if you suspect unauthorized use of your account.</p>

<h2>2. User-Submitted Content</h2>
<p>When you submit a story, chapter, cover image, review, or other content ("User Content"), you retain ownership of it. By submitting User Content, you grant WorldStories a non-exclusive, worldwide, royalty-free license to host, store, reproduce, display, and distribute it on the Site for the purpose of operating and promoting the Site.</p>
<p>Story submissions are reviewed before they are published. We may decline to publish, or may remove, any content that violates these Terms, at our discretion.</p>
<p>You agree that your User Content will not:</p>
<ul>
  <li>Infringe the copyright, trademark, or other intellectual property rights of any third party;</li>
  <li>Contain sexually explicit material involving minors, or unlawful, defamatory, or harassing content;</li>
  <li>Promote violence, hatred, or discrimination against individuals or groups;</li>
  <li>Contain malware or attempt to compromise the security of the Site; or</li>
  <li>Violate any applicable law.</li>
</ul>

<h2>3. Prohibited Conduct</h2>
<ul>
  <li>Impersonating another person or misrepresenting your affiliation with anyone;</li>
  <li>Scraping, data-mining, or using automated means to access the Site beyond normal use;</li>
  <li>Interfering with or disrupting the Site's operation, including view counts or ad delivery;</li>
  <li>Attempting to gain unauthorized access to accounts or systems.</li>
</ul>

<h2>4. Advertising</h2>
<p>The Site may display advertisements, including through Google AdSense and other ad networks, to support the cost of operating WorldStories. You agree not to click your own ads, use automated tools to generate ad impressions or clicks, or otherwise interfere with ad delivery.</p>

<h2>5. Intellectual Property</h2>
<p>The WorldStories name, logo, and Site design are owned by WorldStories. Other than User Content, you may not copy, modify, or distribute any part of the Site without our written permission.</p>

<h2>6. Termination</h2>
<p>We may suspend or terminate your account at any time if we believe you have violated these Terms. You may stop using the Site and request account deletion at any time by contacting us.</p>

<h2>7. Disclaimer of Warranties</h2>
<p>The Site is provided "as is" and "as available" without warranties of any kind, express or implied. We do not guarantee that the Site will be uninterrupted, secure, or error-free, or that content submitted by other users is accurate or appropriate.</p>

<h2>8. Limitation of Liability</h2>
<p>To the fullest extent permitted by law, WorldStories will not be liable for any indirect, incidental, special, or consequential damages arising from your use of the Site.</p>

<h2>9. Changes to These Terms</h2>
<p>We may update these Terms from time to time. Continued use of the Site after changes take effect constitutes acceptance of the revised Terms.</p>

<h2>10. Contact Us</h2>
<p>Questions about these Terms can be sent to worldstoriesnet@gmail.com.</p>
''';

const _privacyHtml = r'''
<p>WorldStories ("WorldStories", "we", "us", or "our") operates worldstories.net (the "Site"), a platform for reading and publishing short stories, novels, and audiobooks. This Privacy Policy explains what information we collect, how we use it, and the choices you have. By using the Site, you agree to the collection and use of information as described here.</p>

<h2>1. Information We Collect</h2>
<h3>Account information</h3>
<p>When you register, we collect your email address, username, and any display name, bio, or avatar you choose to add. If you sign in with Google, we receive the basic profile information Google shares with us (name, email, profile picture) to create and authenticate your account.</p>
<h3>Content you submit</h3>
<p>If you submit a story, chapter, or review, we store that content along with your account association so it can be displayed on the Site and reviewed by our moderators before publication, in the case of story submissions.</p>
<h3>Reading and usage activity</h3>
<p>To power features like "Continue Reading" and to show accurate view counts, we record your reading progress, favorites, and ratings against your account, and we log story views associated with an IP address and timestamp, kept only long enough to avoid counting repeat views from the same visitor. Our analytics also record a coarse country, a non-reversible hash of your IP address, and the website that referred you, so we can understand our audience and detect automated traffic.</p>
<h3>Cookies and similar technologies</h3>
<p>We use browser local storage to keep you signed in, and cookies set by Google for sign-in and, where enabled, by Google AdSense and other advertising partners to serve and measure ads.</p>

<h2>2. How We Use Information</h2>
<ul>
  <li>To provide, operate, and maintain the Site and your account;</li>
  <li>To show you relevant content, such as recommendations and your reading history;</li>
  <li>To moderate submitted content and enforce our Terms of Service;</li>
  <li>To measure aggregate engagement and improve the Site;</li>
  <li>To communicate with you about your account or in response to your inquiries;</li>
  <li>To serve advertising, where applicable.</li>
</ul>

<h2>3. Advertising</h2>
<p>WorldStories may display advertisements served by Google AdSense and other third-party ad networks. These providers may use cookies, device identifiers, or similar technologies to serve ads based on your visits to this and other websites. You can learn more through Google's partner-sites policy and opt out of personalized advertising through Google Ads Settings or aboutads.info.</p>

<h2>4. Sharing of Information</h2>
<p>We do not sell your personal information. We share information only with:</p>
<ul>
  <li>Service providers who host or operate the Site on our behalf;</li>
  <li>Advertising and analytics partners, limited to what is needed to serve and measure ads;</li>
  <li>Authorities, where required to comply with the law or protect the rights and safety of WorldStories and its users.</li>
</ul>

<h2>5. Your Choices and Rights</h2>
<p>You can review and update your account information at any time from your profile. To request access to, correction of, or deletion of your personal data, contact us at worldstoriesnet@gmail.com. Depending on where you live, you may have additional rights under laws such as the GDPR or CCPA; we will respond to verifiable requests consistent with applicable law.</p>

<h2>6. Data Retention</h2>
<p>We retain account and content data for as long as your account is active or as needed to provide the Site. Individual view-tracking records used for de-duplicating counts are kept only briefly and are not used to build a profile of your browsing beyond this Site.</p>

<h2>7. Changes to This Policy</h2>
<p>We may update this Privacy Policy from time to time. We will update the "Last updated" date when we do, and material changes will be reflected on this page.</p>

<h2>8. Contact Us</h2>
<p>If you have questions about this Privacy Policy, contact us at worldstoriesnet@gmail.com.</p>
''';
