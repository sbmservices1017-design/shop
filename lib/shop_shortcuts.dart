import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard navigation in the authenticated ShopDesk shell.
/// The page indices match Shell.menu; navigation is permission-checked there.
class ShopNavigationShortcut {
  final ShortcutActivator activator;
  final String keys;
  final String description;
  final int pageIndex;
  const ShopNavigationShortcut(this.activator, this.keys, this.description, this.pageIndex);
}

const shopNavigationShortcuts = <ShopNavigationShortcut>[
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.f2), 'F2', 'Open POS', 1),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.f3), 'F3', 'Sales Invoices', 2),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.f4), 'F4', 'Purchase Invoices', 4),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit1, control:true), 'Ctrl+1', 'Dashboard', 0),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit2, control:true), 'Ctrl+2', 'POS', 1),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit3, control:true), 'Ctrl+3', 'Sales Invoices', 2),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit4, control:true), 'Ctrl+4', 'Purchase Invoices', 4),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit5, control:true), 'Ctrl+5', 'Products & Variations', 6),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit6, control:true), 'Ctrl+6', 'Stock & Adjustments', 8),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit7, control:true), 'Ctrl+7', 'Customers', 9),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit8, control:true), 'Ctrl+8', 'Reports & Export', 14),
  ShopNavigationShortcut(SingleActivator(LogicalKeyboardKey.digit9, control:true), 'Ctrl+9', 'Settings & Backup', 15),
];

/// Shared help data kept aligned with actual POS key handlers.
const shopOtherShortcuts = <(String, String)>[
  ('F1', 'Show keyboard shortcuts'),
  ('F5', 'Refresh screen (POS cart confirmation)'),
  ('Ctrl+K', 'Search modules'),
  ('Alt+Left', 'Exit POS / back to previous module'),
];
const shopPosShortcuts = <(String, String)>[
  ('Ctrl+F', 'Focus product search'),
  ('Ctrl+S', 'Save Sale / Purchase invoice'),
  ('F6', 'Show / hide payment details'),
];
