import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';


// cw06-bb5d5 (Firebase ID)
// android   1:90390837114:android:ec2702c66b8b9865f148c3

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class Task {
  String id;
  String name;
  bool isCompleted;
  String priority;
  List<String>? subTasks;
  // tasks/{taskId}/subtasks/{subtaskId}

  Task({
    required this.id,
    required this.name,
    this.isCompleted = false,
    this.priority = 'Medium',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'isCompleted': isCompleted,
        'priority': priority,
        'userId': FirebaseAuth.instance.currentUser?.uid,
      };

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      name: map['name'],
      isCompleted: map['isCompleted'],
      priority: map['priority'],
    );
  }
}

Future<void> _ensureSignedIn() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    await FirebaseAuth.instance.signInAnonymously();
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

  void _addTask(String userId) {
    if (_taskController.text.trim().isEmpty) return;
    FirebaseFirestore.instance.collection('tasks').add({
      'name': _taskController.text.trim(),
      'isCompleted': false,
      'priority': _priority,
      'userId': userId,
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

  // Build the UI by listening to FirebaseAuth state changes
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        
        // While waiting for authentication, show a spinner.
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // If no user is signed in, trigger anonymous sign-in and show spinner
        if (!authSnapshot.hasData) {
          FirebaseAuth.instance.signInAnonymously();
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Once authenticated, get the userId
        final userId = authSnapshot.data!.uid;

        return Scaffold(
          appBar: AppBar(title: Text('My Tasks')),
          body: Column(
            children: [
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
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    IconButton(icon: Icon(Icons.add), onPressed: () => _addTask(userId)),
                  ],
                ),
              ),
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
                    if (!snapshot.hasData)
                      return Center(child: CircularProgressIndicator());
                    final tasks = snapshot.data!;
                    return ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (_, i) {
                        final task = tasks[i];
                        return ListTile(
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) => _toggleTask(task),
                          ),
                          title: Text(task.name),
                          subtitle: Text('Priority: ${task.priority}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteTask(task),
                          ),
                          tileColor: task.isCompleted
                              ? Colors.grey[300]
                              : _getPriorityColor(task.priority).withValues(alpha: 0.1),
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
