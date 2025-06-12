# Vikunja Android Home Screen Widget

This document describes the Android home screen widget functionality added to the Vikunja app.

## Features

The Vikunja Android widget provides the following features:

1. **Task Display**: Shows current tasks from the home view directly on the Android home screen
2. **Quick Add Button**: Allows quick addition of new tasks with enhanced functionality
3. **Real-time Updates**: Widget automatically updates when tasks change in the app
4. **Interactive Elements**: Tasks can be checked/unchecked directly from the widget

## Widget Components

### 1. Task Display
- Shows up to several tasks from your home view
- Displays task title, due date, labels, and priority
- Tasks are displayed with checkboxes for quick completion
- Empty state shown when no tasks are available

### 2. Quick Add Functionality
The widget includes an enhanced quick add feature that supports:
- **Task Name**: Required field for the task title
- **Description**: Optional detailed description
- **Due Date**: Choose from preset options (1 day, 1 week, 1 month) or custom date
- **Labels**: Select from existing labels to categorize the task

## Installation and Setup

### Prerequisites
- Android 7.0 (API level 24) or higher
- Vikunja app installed and configured
- At least one project configured in the app

### Adding the Widget
1. Long-press on your Android home screen
2. Select "Widgets" from the menu
3. Find "Vikunja" in the widget list
4. Drag the "Vikunja Tasks" widget to your home screen
5. The widget will automatically display your current tasks

## Usage

### Viewing Tasks
- The widget shows tasks from your home view (same as the landing page in the app)
- Tasks display title, due date (if set), labels, and priority indicators
- The widget header shows the total number of tasks

### Adding Tasks
1. Tap the "+" button in the widget header
2. The quick add dialog will open with the following fields:
   - **Task Name**: Enter the task title (required)
   - **Description**: Add optional details
   - **Due Date**: Select from quick options or choose custom date
   - **Labels**: Select applicable labels from your existing labels
3. Tap "ADD TASK" to create the task
4. The widget will automatically refresh to show the new task

### Completing Tasks
- Tap the checkbox next to any task to mark it as complete
- Completed tasks will be removed from the widget view
- Changes sync automatically with the main app

## Technical Implementation

### Architecture
The widget implementation consists of several components:

1. **Flutter Side**:
   - `WidgetService`: Manages widget data and updates
   - `QuickAddTaskDialog`: Enhanced task creation dialog
   - Integration with existing task management

2. **Android Native**:
   - `VikunjaWidgetProvider`: Main widget provider
   - `VikunjaWidgetService`: Service for list data
   - `VikunjaWidgetFactory`: Factory for creating list items

### Data Flow
1. Flutter app loads tasks from API
2. `WidgetService` converts tasks to JSON format
3. Data is saved to shared preferences via `home_widget` plugin
4. Android widget provider reads data and updates UI
5. User interactions in widget trigger app launches or API calls

### Widget Updates
The widget updates automatically when:
- Tasks are added, modified, or completed in the main app
- The app is refreshed or synced
- Widget refresh interval expires (30 minutes)

## Customization

### Widget Size
The widget supports multiple sizes:
- **Small (2x2)**: Shows up to 3 tasks
- **Medium (4x2)**: Shows up to 6 tasks  
- **Large (4x3)**: Shows up to 9 tasks

### Theming
The widget uses system-appropriate colors and follows Material Design guidelines:
- Light theme for light system themes
- Consistent colors with the main app
- High contrast for accessibility

## Troubleshooting

### Widget Not Updating
1. Ensure the Vikunja app is not restricted by battery optimization
2. Check that background app refresh is enabled
3. Manually refresh by opening the main app
4. Remove and re-add the widget if issues persist

### Quick Add Not Working
1. Ensure you have at least one project configured
2. Check that you have permission to add tasks
3. Verify network connectivity
4. Check app permissions for notifications

### Empty Widget
1. Ensure you have tasks in your home view
2. Check filter settings in the main app
3. Verify you're logged in to your Vikunja instance
4. Check network connectivity

## Limitations

1. Widget shows tasks from home view only (not project-specific)
2. Limited number of tasks displayed based on widget size
3. Requires periodic app launch for optimal synchronization
4. Labels and due dates display in simplified format

## Future Enhancements

Potential future improvements:
- Widget configuration options
- Multiple widget instances for different projects
- Dark theme support
- Resizable widget layouts
- Task priority color coding
- Swipe actions for task management

## Support

For issues with the widget functionality:
1. Check the troubleshooting section above
2. Ensure you're using the latest version of the app
3. Report bugs through the main app's feedback mechanism
4. Include widget size and Android version in bug reports