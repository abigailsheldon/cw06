import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Need a signed-in user before running app
  await FirebaseAuth.instance.signInAnonymously();
  runApp(MyApp());
}

// Helper function to convert priority to a numeric value for sorting.
int priorityValue(String priority) {
  switch (priority) {
    case "High":
      return 3;
    case "Medium":
      return 2;
    case "Low":
      return 1;
    default:
      return 0;
  }
}

class Task {
  String id;
  String name;
  bool isCompleted;
  String priority;
  List<String> subTasks; // Will store subtasks as a list of strings

  Task({
    required this.id,
    required this.name,
    this.isCompleted = false,
    this.priority = 'Medium',
    List<String>? subTasks,
  }) : this.subTasks = subTasks ?? [];

  Map<String, dynamic> toMap() => {
        'name': name,
        'isCompleted': isCompleted,
        'priority': priority,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'subTasks': subTasks,
      };

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      name: map['name'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      priority: map['priority'] ?? 'Medium',
      subTasks: map['subTasks'] != null ? List<String>.from(map['subTasks']) : [],
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  String _priority = 'Medium';

  /* Sorting */
  // Options: "None", "Priority High-Low", "Priority Low-High", "Completion Status"
  String _sortCriterion = "None";
  
  /* Filtering */ 
  // Options: "All", "Completed", "Pending"
  String _filterCriterion = "All";

  /* Adds a new task document in Firestore. */
  void _addTask(String userId) {
    if (_taskController.text.trim().isEmpty) return;
    FirebaseFirestore.instance.collection('tasks').add({
      'name': _taskController.text.trim(),
      'isCompleted': false,
      'priority': _priority,
      'userId': userId,
      'subTasks': [], // Start with an empty subtask list
    });
    _taskController.clear();
    setState(() => _priority = 'Medium');
  }

  void _toggleTask(Task task) {
    FirebaseFirestore.instance
        .collection('tasks')
        .doc(task.id)
        .update({'isCompleted': !task.isCompleted});
  }

  void _deleteTask(Task task) {
    FirebaseFirestore.instance.collection('tasks').doc(task.id).delete();
  }

  /* Adds a subtask to the given task. */
  void _addSubTask(Task task, String subTask) {
    FirebaseFirestore.instance.collection('tasks').doc(task.id).update({
      'subTasks': FieldValue.arrayUnion([subTask])
    });
  }

  /* Opens dialog to input a new subtask. */
  // To add subtask, click on task and button appears
  void _showAddSubTaskDialog(Task task) {
    final TextEditingController _subTaskController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Subtask'),
        content: TextField(
          controller: _subTaskController,
          decoration: InputDecoration(hintText: 'Enter subtask'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final subTask = _subTaskController.text.trim();
              if (subTask.isNotEmpty) {
                _addSubTask(task, subTask);
              }
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Firebase auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show spinner while waiting
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // If no user, sign in anonymously
        if (!authSnapshot.hasData) {
          FirebaseAuth.instance.signInAnonymously();
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userId = authSnapshot.data!.uid;
        return Scaffold(
          appBar: AppBar(
            title: Text('My Tasks'),
            actions: [
              IconButton(
                icon: Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
              )
            ],
          ),
          body: Column(
            children: [
              
              // Input row for new tasks
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskController,
                        decoration: InputDecoration(
                          labelText: 'Enter task name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _priority,
                      onChanged: (val) => setState(() => _priority = val!),
                      items: ['High', 'Medium', 'Low']
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () => _addTask(userId),
                    ),
                  ],
                ),
              ),
              
              // Sorting and filtering
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    
                    // Sorting dropdown
                    Text("Sort by: "),
                    DropdownButton<String>(
                      value: _sortCriterion,
                      onChanged: (val) => setState(() => _sortCriterion = val!),
                      items: [
                        "None",
                        "Priority High-Low",
                        "Priority Low-High",
                        "Completion Status"
                      ]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    SizedBox(width: 16),
                    
                    // Filtering dropdown
                    Text("Filter: "),
                    DropdownButton<String>(
                      value: _filterCriterion,
                      onChanged: (val) =>
                          setState(() => _filterCriterion = val!),
                      items: ["All", "Completed", "Pending"]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                  ],
                ),
              ),
              
              // Task list
              Expanded(
                child: StreamBuilder<List<Task>>(
                  stream: FirebaseFirestore.instance
                      .collection('tasks')
                      .where('userId', isEqualTo: userId)
                      .snapshots()
                      .map((snapshot) => snapshot.docs
                          .map((doc) => Task.fromMap(doc.id, doc.data()))
                          .toList()),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    
                    // Get tasks from snapshot
                    List<Task> tasks = snapshot.data!;
                    
                    // Filtering
                    if (_filterCriterion == "Completed") {
                      tasks = tasks.where((t) => t.isCompleted).toList();
                    } else if (_filterCriterion == "Pending") {
                      tasks = tasks.where((t) => !t.isCompleted).toList();
                    }
                    
                    // Sorting
                    if (_sortCriterion == "Priority High-Low") {
                      tasks.sort((a, b) =>
                          priorityValue(b.priority).compareTo(priorityValue(a.priority)));
                    } else if (_sortCriterion == "Priority Low-High") {
                      tasks.sort((a, b) =>
                          priorityValue(a.priority).compareTo(priorityValue(b.priority)));
                    } else if (_sortCriterion == "Completion Status") {
                      
                      // Pending tasks first, then completed
                      tasks.sort((a, b) {
                        if (a.isCompleted == b.isCompleted) return 0;
                        return a.isCompleted ? 1 : -1;
                      });
                    }
                    return ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ExpansionTile(
                          title: Row(
                            children: [
                              Checkbox(
                                value: task.isCompleted,
                                onChanged: (_) => _toggleTask(task),
                              ),
                              Expanded(
                                child: Text(
                                  task.name,
                                  style: TextStyle(
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Priority: ${task.priority}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteTask(task),
                          ),
                          // Set a background color based on priority
                          backgroundColor: task.isCompleted
                              ? Colors.grey[300]
                              : _getPriorityColor(task.priority).withValues(alpha: 0.1),
                          children: [
                            
                            // List existing subtasks
                            if (task.subTasks.isNotEmpty)
                              ...task.subTasks.map((subTask) => ListTile(
                                    title: Text(subTask),
                                  )),
                           
                            // Button to add a new subtask.
                            ListTile(
                              leading: Icon(Icons.add),
                              title: Text("Add subtask"),
                              onTap: () => _showAddSubTaskDialog(task),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
