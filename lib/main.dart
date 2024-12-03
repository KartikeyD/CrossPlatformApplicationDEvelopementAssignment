import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'login_page.dart'; // Import login page
import 'register_page.dart'; // Import register page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const keyApplicationId = 'rEEnMool4bm1q6U9TY62fepdX9YnbqmrjfPQpQWS'; // Replace with your App ID
  const keyClientKey = '92mE49QX4F2U1DAyZMxPGDWbSo2KYADyeWd9QfVb'; // Replace with your Client Key
  const keyParseServerUrl = 'https://parseapi.back4app.com'; // Replace with your Parse Server URL

  await Parse().initialize(
    keyApplicationId,
    keyParseServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Task',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}

class Task {
  String? id;
  String? title;
  String? description;
  DateTime? dueDate;
  bool isComplete;

  Task({this.id, this.title, this.description, this.dueDate, this.isComplete = false});

  // Convert Task object to ParseObject for saving to Parse
  ParseObject toParseObject() {
    final parseObject = ParseObject('Task');
    parseObject.set('title', title);
    parseObject.set('description', description);
    parseObject.set('dueDate', dueDate);
    parseObject.set('isComplete', isComplete); // Ensure isComplete is set
    return parseObject;
  }

  // Convert ParseObject back to Task object
  static Task fromParseObject(ParseObject parseObject) {
    return Task(
      id: parseObject.objectId!,
      title: parseObject.get<String>('title'),
      description: parseObject.get<String>('description'),
      dueDate: parseObject.get<DateTime>('dueDate'),
      isComplete: parseObject.get<bool>('isComplete') ?? false,
    );
  }
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  // Fetch tasks from Parse server
  Future<void> _fetchTasks() async {
    final query = QueryBuilder(ParseObject('Task'))
      ..orderByDescending('createdAt');

    final response = await query.query();

    if (response.success) {
      setState(() {
        tasks = (response.results as List)
            .map((e) => Task.fromParseObject(e))
            .toList();
      });
    } else {
      print('Error fetching tasks: ${response.error!.message}');
    }
  }

  // Toggle task completion (complete/incomplete)
  Future<void> _toggleTaskCompletion(Task task) async {
    task.isComplete = !task.isComplete; // Toggle the completion status

    final parseObject = task.toParseObject();
    parseObject.set('isComplete', task.isComplete);

    final response = await parseObject.save();

    if (response.success) {
      setState(() {
        task.isComplete = task.isComplete; // Update task status
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task status updated')));
    } else {
      print('Error updating task: ${response.error!.message}');
    }
  }

  // Delete task from Parse server
  Future<void> _deleteTask(Task task) async {
    final parseObject = ParseObject('Task')..objectId = task.id;

    final response = await parseObject.delete();

    if (response.success) {
      setState(() {
        tasks.removeWhere((t) => t.id == task.id); // Remove the task from local list
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task deleted')));
    } else {
      print('Error deleting task: ${response.error!.message}');
    }
  }

  // Add a new task by navigating to the TaskCreationPage
  void _addNewTask() async {
    final newTask = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskCreationPage()),
    );

    if (newTask != null) {
      setState(() {
        tasks.add(newTask);
      });
      _saveNewTask(newTask); // Save task to Parse
    }
  }

  // Save task to Parse after creating it
  Future<void> _saveNewTask(Task task) async {
    final parseObject = task.toParseObject();

    final response = await parseObject.save();

    if (response.success) {
      setState(() {
        tasks.add(task); // Add the task to the list after saving
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task added successfully')));
    } else {
      print('Error saving task: ${response.error!.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quick Task - Home'),
        backgroundColor: Color(0xFF4F6D98),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Tasks List', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.blue),
                  onPressed: _addNewTask, // Open task creation page
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  child: ListTile(
                    title: Text(task.title!),
                    subtitle: Text('Due Date: ${task.dueDate != null ? task.dueDate!.toLocal().toString().split(' ')[0] : 'N/A'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            task.isComplete ? Icons.check_box : Icons.check_box_outline_blank,
                            color: task.isComplete ? Colors.green : null,
                          ),
                          onPressed: () {
                            _toggleTaskCompletion(task); // Toggle task completion
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteTask(task); // Delete task
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskCreationPage extends StatefulWidget {
  @override
  _TaskCreationPageState createState() => _TaskCreationPageState();
}

class _TaskCreationPageState extends State<TaskCreationPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _dueDate;

  // Open date picker for due date
  Future<void> _selectDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _dueDate) {
      setState(() {
        _dueDate = pickedDate;
      });
    }
  }

  // Save the new task
  void _saveTask() {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty || _dueDate == null) {
      return;
    }

    final newTask = Task(
      title: _titleController.text,
      description: _descriptionController.text,
      dueDate: _dueDate,
    );

    Navigator.pop(context, newTask); // Return the created task to the Home screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Task'),
        backgroundColor: Color(0xFF4F6D98),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Task Description'),
            ),
            Row(
              children: [
                Text(_dueDate != null ? _dueDate!.toLocal().toString().split(' ')[0] : 'Select Date'),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: _selectDueDate,
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveTask,
              child: Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
}
