import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'legal_documents.dart';
import 'markdown_lite.dart';

/// Opens one document.
void openLegalDocument(BuildContext context, String id, {AssetBundle? bundle}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) =>
        LegalDocumentPage(document: legalDocument(id), bundle: bundle),
  ));
}

/// Account → Legal: every document, in reading order.
class LegalHubPage extends StatelessWidget {
  const LegalHubPage({super.key, this.bundle});

  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: 'Legal',
        subtitle: 'Privacy, terms and notices. No tracking, no analytics.',
        children: [
          SettingsSection(
            title: 'Documents',
            children: [
              for (final doc in legalDocuments)
                SettingsTile(
                  icon: doc.icon,
                  title: doc.title,
                  subtitle: doc.summary,
                  onTap: () =>
                      openLegalDocument(context, doc.id, bundle: bundle),
                ),
            ],
          ),
        ],
      );
}

/// Loads `legal/<id>.md` from the app bundle and shows it.
class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.document, this.bundle});

  final LegalDocument document;
  final AssetBundle? bundle;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late final Future<List<MdBlock>> _blocks;

  @override
  void initState() {
    super.initState();
    final bundle = widget.bundle ?? rootBundle;
    _blocks = bundle
        .loadString(widget.document.asset)
        .then((text) => parseMarkdown(text));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MdBlock>>(
        future: _blocks,
        builder: (context, snapshot) {
          final blocks = snapshot.data;
          return SettingsPage(
            title: widget.document.title,
            subtitle: widget.document.summary,
            children: [
              if (snapshot.hasError)
                const SoftCard(
                  child: Text(
                      'This document could not be loaded. Please reinstall or update the app.'),
                )
              else if (blocks == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SelectionArea(child: MarkdownBody(blocks: blocks)),
            ],
          );
        },
      );
}

/// Renders the blocks from [parseMarkdown] with the app's text styles.
class MarkdownBody extends StatelessWidget {
  const MarkdownBody({super.key, required this.blocks});

  final List<MdBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var skippedTitle = false;
    final children = <Widget>[];

    for (final block in blocks) {
      switch (block) {
        case MdHeading(:final level, :final spans):
          // The page already shows the title as its own heading.
          if (level == 1 && !skippedTitle) {
            skippedTitle = true;
            continue;
          }
          children.add(Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.lg, bottom: AppSpacing.xs),
            child: Semantics(
              header: true,
              child: _rich(
                context,
                spans,
                level <= 2
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.titleMedium,
                bold: true,
              ),
            ),
          ));
        case MdParagraph(:final spans):
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _rich(context, spans, theme.textTheme.bodyLarge),
          ));
        case MdListItem(:final marker, :final spans):
          children.add(Padding(
            padding: const EdgeInsets.only(
                bottom: AppSpacing.xs, left: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 28,
                    child: Text(marker, style: theme.textTheme.bodyLarge)),
                Expanded(
                    child: _rich(context, spans, theme.textTheme.bodyLarge)),
              ],
            ),
          ));
        case MdRule():
          children.add(const Divider(height: AppSpacing.xl));
        case MdTable():
          children.add(_Table(table: block));
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

Widget _rich(BuildContext context, List<MdSpan> spans, TextStyle? base,
    {bool bold = false}) {
  final scheme = Theme.of(context).colorScheme;
  return Text.rich(
    TextSpan(
      style: base,
      children: [
        for (final span in spans)
          TextSpan(
            text: span.text,
            style: TextStyle(
              fontWeight: span.bold || bold ? FontWeight.w700 : null,
              fontFamily: span.code ? 'monospace' : null,
              backgroundColor: span.placeholder
                  ? scheme.tertiaryContainer
                  : span.code
                      ? scheme.surfaceContainerHighest
                      : null,
              color: span.placeholder ? scheme.onTertiaryContainer : null,
            ),
          ),
      ],
    ),
  );
}

/// Tables become stacked rows so they read well on a phone: the first column
/// is the row's title and the other columns follow it, labelled when long.
class _Table extends StatelessWidget {
  const _Table({required this.table});

  final MdTable table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final longest = table.rows.expand((row) => row.skip(1)).fold<int>(
        0,
        (max, cell) =>
            plainText(cell).length > max ? plainText(cell).length : max);
    final labelled = longest > 40;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            for (var r = 0; r < table.rows.length; r++) ...[
              if (r > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (table.rows[r].isNotEmpty)
                      _rich(context, table.rows[r].first,
                          theme.textTheme.titleSmall,
                          bold: true),
                    if (labelled)
                      for (var c = 1; c < table.rows[r].length; c++)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _rich(
                            context,
                            [
                              if (c < table.headers.length)
                                MdSpan('${plainText(table.headers[c])}: ',
                                    bold: true),
                              ...table.rows[r][c],
                            ],
                            theme.textTheme.bodyMedium,
                          ),
                        )
                    else if (table.rows[r].length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _rich(
                          context,
                          [
                            for (var c = 1; c < table.rows[r].length; c++) ...[
                              if (c > 1) const MdSpan('  ·  '),
                              ...table.rows[r][c],
                            ],
                          ],
                          theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
