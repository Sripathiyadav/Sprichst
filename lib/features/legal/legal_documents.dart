import 'package:flutter/material.dart';

/// One bundled document from the `legal/` folder.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
  });

  /// File name without extension; the asset is `legal/<id>.md`.
  final String id;
  final String title;
  final String summary;
  final IconData icon;

  String get asset => 'legal/$id.md';
}

/// The documents shown in the app, in reading order. `pubspec.yaml` lists the
/// same files as assets and a test keeps the two in step.
const legalDocuments = <LegalDocument>[
  LegalDocument(
    id: 'privacy-policy',
    title: 'Privacy Policy',
    summary: 'What data is handled, why, who receives it, and for how long.',
    icon: Icons.privacy_tip_outlined,
  ),
  LegalDocument(
    id: 'terms-of-service',
    title: 'Terms of Service',
    summary: 'The agreement for using Sprichst.',
    icon: Icons.gavel_outlined,
  ),
  LegalDocument(
    id: 'your-rights',
    title: 'Your rights',
    summary: 'Access, export, correct and erase your data, by region.',
    icon: Icons.verified_user_outlined,
  ),
  LegalDocument(
    id: 'ai-transparency',
    title: 'AI transparency',
    summary: 'How the AI tutor works, where messages go, and its limits.',
    icon: Icons.smart_toy_outlined,
  ),
  LegalDocument(
    id: 'cookies-and-storage',
    title: 'Cookies and storage',
    summary: 'What is saved on your device. No tracking.',
    icon: Icons.storage_outlined,
  ),
  LegalDocument(
    id: 'disclaimer',
    title: 'Disclaimer',
    summary: 'Results are not guaranteed; AI can be wrong; exam names.',
    icon: Icons.info_outline,
  ),
  LegalDocument(
    id: 'copyright-and-takedown',
    title: 'Copyright and takedown',
    summary: 'Report infringement to our designated copyright agent.',
    icon: Icons.copyright,
  ),
  LegalDocument(
    id: 'security-summary',
    title: 'Security',
    summary: 'How your data and the AI server are protected.',
    icon: Icons.shield_outlined,
  ),
  LegalDocument(
    id: 'accessibility',
    title: 'Accessibility',
    summary: 'What works, what does not yet, and how to tell us.',
    icon: Icons.accessibility_new_outlined,
  ),
  LegalDocument(
    id: 'impressum',
    title: 'Impressum',
    summary: 'Provider information required in Germany and the EU.',
    icon: Icons.business_outlined,
  ),
  LegalDocument(
    id: 'third-party-notices',
    title: 'Open-source notices',
    summary: 'Software, fonts and AI models used, with their licences.',
    icon: Icons.article_outlined,
  ),
];

LegalDocument legalDocument(String id) =>
    legalDocuments.firstWhere((doc) => doc.id == id);
