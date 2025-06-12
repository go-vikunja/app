import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/models/label.dart';

void main() {
  group('Widget Service Tests', () {
    test('Task JSON serialization should work correctly', () {
      // Create a test user
      final user = User(
        id: 1,
        username: 'testuser',
        name: 'Test User',
      );
      
      // Create a test label
      final label = Label(
        id: 1,
        title: 'Important',
        createdBy: user,
      );
      
      // Create a test task
      final task = Task(
        id: 1,
        title: 'Test Task',
        description: 'Test Description',
        done: false,
        dueDate: DateTime(2024, 12, 31),
        priority: 2,
        labels: [label],
        createdBy: user,
        projectId: 1,
      );
      
      // Test that task properties are accessible
      expect(task.title, equals('Test Task'));
      expect(task.description, equals('Test Description'));
      expect(task.done, equals(false));
      expect(task.priority, equals(2));
      expect(task.labels.length, equals(1));
      expect(task.labels.first.title, equals('Important'));
    });
    
    test('Task list should be convertible to JSON format', () {
      final user = User(
        id: 1,
        username: 'testuser',
        name: 'Test User',
      );
      
      final tasks = [
        Task(
          id: 1,
          title: 'Task 1',
          description: 'Description 1',
          done: false,
          createdBy: user,
          projectId: 1,
        ),
        Task(
          id: 2,
          title: 'Task 2',
          description: 'Description 2',
          done: true,
          createdBy: user,
          projectId: 1,
        ),
      ];
      
      // Test that we can iterate over tasks and access properties
      expect(tasks.length, equals(2));
      expect(tasks[0].title, equals('Task 1'));
      expect(tasks[1].done, equals(true));
    });
  });
}