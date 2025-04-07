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

class MyApp extends StatelessWidget {

  // This widget is the root of your application.
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
  String get _userId => FirebaseAuth.instance.currentUser!.uid;


  void _addTask(){
  if (_taskController.text.trim().isEmpty) return;
    FirebaseFirestore.instance.collection('tasks').add({
      'name': _taskController.text.trim(),
      'isCompleted': false,
      'priority': _priority,
      'userId': _userId,
    });
    _taskController.clear();
    setState(() => _priority = 'Medium');
  }

  void _toggleTask(){
    
  }

  void _deleteTask(Task task){
    FirebaseFirestore.instance.collection('tasks').doc(task.id).delete();
  }

  Stream<List<Task>> _getTasks() {

  }

  Color _getPriorityColor(String priority) {
  }

  @override
  Widget build(BuildContext context){


  }
}