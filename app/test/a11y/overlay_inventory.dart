/// How the sweep covers one dialog, sheet, picker or menu call in
/// `app/lib`: an overlay scenario of the registry, or an exemption with
/// the reason.
sealed class OverlayCoverage {
  const new();
}

final class Swept extends OverlayCoverage {
  const new(this.scenario);

  final String scenario;
}

final class Exempt extends OverlayCoverage {
  const new(this.reason);

  final String reason;
}

const _menuOfTextItems =
    'a Material popup menu of text items; its labelled button is swept with '
    'the page, and the items are 48 dp rows that read their text';
const _sameAlertAsDelete =
    'an AlertDialog.adaptive with a title, a text and AdaptiveDialogAction '
    'buttons, built like the delete-task dialog the sweep opens';

/// Every call `overlay_sites.dart` finds, keyed as it keys them. A new
/// call needs an entry; an entry whose call is gone fails too.
const overlayInventory = <String, OverlayCoverage>{
  'app/layout/readable_sheet.dart '
      'showReadableCupertinoSheet showCupertinoSheet': Exempt(
    'the shared iOS sheet presenter; its callers are listed',
  ),
  'features/about/presentation/about_page.dart '
      'AboutPage._showLicences MaterialPageRoute': Exempt(
    "Flutter's LicensePage, whose app bars mark their titles as headers "
    'without a heading level, so it would fail the heading guideline; a D68 '
    'deviation (framework headings without a level). Opened in '
    'test/features/about/about_page_test.dart',
  ),
  'features/account_settings/presentation/account_deletion.dart '
      'confirmAccountDeletion showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/account_settings/presentation/avatar_page.dart '
      '_AvatarPageState._uploadPhoto MaterialPageRoute': Swept(
    'avatar crop page',
  ),
  'features/account_settings/presentation/caldav_page.dart '
      '_CaldavPageState._create MaterialPageRoute': Swept(
    'one-time secret page',
  ),
  'features/account_settings/presentation/one_time_secret_view.dart '
      '_OneTimeSecretViewState._confirmLeave showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/account_settings/presentation/sessions_page.dart '
      '_SessionRow.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/accounts/presentation/account_switcher_sheet.dart '
      'showAccountSwitcher showReadableCupertinoSheet': Swept(
    'account switcher',
  ),
  'features/accounts/presentation/account_switcher_sheet.dart '
      'showAccountSwitcher showModalBottomSheet': Swept(
    'account switcher',
  ),
  'features/accounts/presentation/accounts_section.dart '
      '_AccountMenu.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/accounts/presentation/remove_account_dialog.dart '
      'confirmRemoveAccount showAdaptiveDialog': Swept(
    'sign-out dialog',
  ),
  'features/common/presentation/day_picker.dart pickDay showDatePicker': Exempt(
    'the Material date picker dialog of the date-time picker '
    'scenario; on iOS the Cupertino wheel of showCupertinoPickerSheet',
  ),
  'features/common/presentation/day_range_picker.dart '
      'pickDayRange showCupertinoModalPopup': Swept(
    'day-range picker',
  ),
  'features/common/presentation/day_range_picker.dart '
      '_pickWithMaterialDialogs showDatePicker': Swept(
    'day-range picker',
  ),
  'features/common/presentation/day_range_picker.dart '
      '_pickWithMaterialDialogs showDatePicker#2': Exempt(
    'the same Material date picker dialog as the first day, for '
    'the last day of the range',
  ),
  'features/common/presentation/option_sheet.dart '
      'showOptionSheet showReadableCupertinoSheet': Swept(
    'option sheet',
  ),
  'features/common/presentation/option_sheet.dart '
      'showOptionSheet showModalBottomSheet': Swept(
    'option sheet',
  ),
  'features/connection/presentation/browser_leg_hint.dart '
      'confirmBrowserLeg showAdaptiveDialog': Exempt(
    'swept as the "browser hint" state of the server overview',
  ),
  'features/description_editor/presentation/description_editor_page.dart '
      '_DescriptionEditorPageState._askAboutChange showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/description_editor/presentation/description_editor_page.dart '
      '_DescriptionEditorPageState._askToRestore showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened in '
    'test/features/description_editor/description_editor_page_test.dart',
  ),
  'features/description_editor/presentation/description_editor_page.dart '
      '_DescriptionEditorPageState._confirmLeave showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/description_editor/presentation/editor_toolbar.dart '
      '_HeadingMenu.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/description_editor/presentation/editor_toolbar.dart '
      '_ImageMenu.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/description_editor/presentation/editor_toolbar.dart '
      '_TableMenu.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/inbox/presentation/inbox_screen.dart '
      '_InboxScreenState.build PopupMenuButton': Exempt(
    _menuOfTextItems,
  ),
  'features/labels/presentation/labels_page.dart '
      '_LabelRow.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_organise_test.dart',
  ),
  'features/onboarding/presentation/connect/insecure_connection_dialog.dart '
      'confirmInsecureConnection showAdaptiveDialog': Exempt(
    'swept as the "connect insecure question" state of the connect '
    'screen',
  ),
  'features/projects/presentation/board/column_menu.dart '
      'ColumnMenuButton.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/projects/presentation/manage/project_confirmations.dart '
      'confirmDiscardChanges showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened in '
    'test/features/projects/project_edit_page_test.dart',
  ),
  'features/projects/presentation/manage/project_views_page.dart '
      '_ViewRow.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/projects/presentation/project_tasks_screen.dart '
      '_ProjectTasksScreenState.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/projects/presentation/projects_screen.dart '
      '_ProjectsScreenState.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/quick_add/presentation/quick_add_help_sheet.dart '
      'showQuickAddHelp showModalBottomSheet': Exempt(
    'a scrolling text sheet; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/share/presentation/open_shared_link_sheet.dart '
      'askToOpenSharedLink showReadableCupertinoSheet': Exempt(
    'a sheet of three labelled choices; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/share/presentation/open_shared_link_sheet.dart '
      'askToOpenSharedLink showModalBottomSheet': Exempt(
    'a sheet of three labelled choices; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/share/presentation/share_sheet.dart '
      'showShareSheet showReadableCupertinoSheet': Exempt(
    'opened at 200 % in both modes in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/share/presentation/share_sheet.dart '
      'showShareSheet showModalBottomSheet': Exempt(
    'opened at 200 % in both modes in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/smart_lists/presentation/smart_list_screen.dart '
      '_SmartListScreenState._menu PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/tasks/presentation/confirm_dialog.dart '
      'confirmAdaptive showAdaptiveDialog': Exempt(
    _sameAlertAsDelete,
  ),
  'features/tasks/presentation/create/new_task_sheet.dart '
      'showNewTaskSheet showModalBottomSheet': Swept(
    'new-task sheet',
  ),
  'features/tasks/presentation/delete_task_dialog.dart '
      'confirmDeleteTask showAdaptiveDialog': Swept(
    'delete-task dialog',
  ),
  'features/tasks/presentation/details/attachment_row.dart '
      'AttachmentRow.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/tasks/presentation/details/attachments_section.dart '
      '_TaskAttachmentsSectionState.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/tasks/presentation/details/comments_section.dart '
      '_CommentMenu.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/tasks/presentation/edit/discard_changes_dialog.dart '
      'confirmDiscardChanges showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/tasks/presentation/open/account_picker.dart '
      'pickAccount showReadableCupertinoSheet': Exempt(
    'a list of labelled account rows for a link that names no '
    'account; opened in test/app/deep_link_test.dart',
  ),
  'features/tasks/presentation/open/account_picker.dart '
      'pickAccount showModalBottomSheet': Exempt(
    'a list of labelled account rows for a link that names no '
    'account; opened in test/app/deep_link_test.dart',
  ),
  'features/tasks/presentation/pickers/cupertino_picker_sheet.dart '
      'showCupertinoPickerSheet showCupertinoModalPopup': Swept(
    'date-time picker',
  ),
  'features/tasks/presentation/pickers/date_time_picker.dart '
      '_pickWithMaterialDialogs showDatePicker': Swept(
    'date-time picker',
  ),
  'features/tasks/presentation/pickers/date_time_picker.dart '
      '_pickWithMaterialDialogs showTimePicker': Exempt(
    'the Material time picker dialog of the time picker scenario, '
    'shown after the date',
  ),
  'features/tasks/presentation/pickers/picker_sheet.dart '
      'showPickerSheet showReadableCupertinoSheet': Swept(
    'label picker',
  ),
  'features/tasks/presentation/pickers/picker_sheet.dart '
      'showPickerSheet showModalBottomSheet': Swept(
    'label picker',
  ),
  'features/tasks/presentation/pickers/project_picker.dart '
      'pickProject showReadableCupertinoSheet': Swept(
    'project picker',
  ),
  'features/tasks/presentation/pickers/project_picker.dart '
      'pickProject showModalBottomSheet': Swept(
    'project picker',
  ),
  'features/tasks/presentation/pickers/time_picker.dart '
      'pickTimeOfDay showTimePicker': Swept(
    'time picker',
  ),
  'features/tasks/presentation/rich_text/attachment_image_viewer.dart '
      'showAttachmentImage MaterialPageRoute': Swept(
    'image viewer',
  ),
  'features/tasks/presentation/task_detail_sheet.dart '
      'showTaskDetail showReadableCupertinoSheet': Swept(
    'detail sheet',
  ),
  'features/tasks/presentation/task_detail_sheet.dart '
      'showTaskDetail showModalBottomSheet': Swept(
    'detail sheet',
  ),
  'features/tasks/presentation/task_detail_sheet.dart '
      '_TaskDetailSheetState.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/teams/presentation/team_confirmations.dart '
      'explainOnlyAdmin showAdaptiveDialog': Exempt(
    '$_sameAlertAsDelete; opened at 200 % in '
    'test/app/accessibility_smoke_organise_test.dart',
  ),
  'features/teams/presentation/team_page.dart '
      '_MemberRow.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_organise_test.dart',
  ),
  'features/upcoming/presentation/upcoming_screen.dart '
      '_UpcomingScreenState.build PopupMenuButton': Exempt(
    '$_menuOfTextItems; opened at 200 % in '
    'test/app/accessibility_smoke_test.dart',
  ),
  'features/widgets/presentation/widget_configure_page.dart '
      '_WidgetConfigurePageState._pick showModalBottomSheet': Exempt(
    'a list of labelled choices like the option sheet; opened at '
    '200 % in test/app/accessibility_smoke_widgets_test.dart',
  ),
};
