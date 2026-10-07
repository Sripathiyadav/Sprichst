/// Width thresholds for the responsive layout, in logical pixels.
///
/// Two families: [compact] and [expanded] describe the whole window and pick
/// the navigation style; [narrowContent] and [twoColumnContent] describe the
/// space inside a page, which is smaller than the window when a rail is shown.
abstract final class Breakpoints {
  /// Below this, phones: bottom navigation.
  static const compact = 600.0;

  /// At or above this, desktops: an extended navigation rail.
  static const expanded = 1024.0;

  /// Page content narrower than this stacks the heading and its trailing widget.
  static const narrowContent = 480.0;

  /// Page content at least this wide may lay cards out in two columns.
  static const twoColumnContent = 560.0;

  /// Page content at least this wide may show a side panel beside the main pane.
  static const sideBySideContent = 820.0;
  static const sidePanelWidth = 260.0;
  static const messageMaxWidth = 560.0;

  static const contentMaxWidth = 1100.0;
  static const lessonMaxWidth = 720.0;
}

enum NavigationLayout { bottomBar, rail, extendedRail }

extension NavigationLayoutForWidth on double {
  NavigationLayout get navigationLayout {
    if (this < Breakpoints.compact) return NavigationLayout.bottomBar;
    if (this < Breakpoints.expanded) return NavigationLayout.rail;
    return NavigationLayout.extendedRail;
  }
}
