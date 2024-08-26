import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart'; // Import vibration package
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart' as tz;
import 'package:intl/intl.dart';

void main() {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AlarmHomePage(),
    );
  }
}

class AlarmHomePage extends StatefulWidget {
  @override
  _AlarmHomePageState createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  DateTime? _alarmTime;
  DateTime? _alarmSetTime;
  String _currentTime = '';
  final tz.Location _localLocation = tz.getLocation('Asia/Seoul');
  Timer? _vibrationTimer;
  bool _isAlarmActive = false;
  List<Map<String, dynamic>> _alarmLogs = []; // Changed to store dynamic values
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _updateTime();
  }

  void _updateTime() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      final now = tz.TZDateTime.now(_localLocation);
      setState(() {
        _currentTime = DateFormat('yyyy/MM/dd HH:mm:ss').format(DateTime.now());
        if (_alarmTime != null && now.isAfter(_alarmTime!)) {
          _triggerAlarm();
          _alarmTime = null;
        }
      });
    });
  }

  void _setAlarm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Set Alarm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Pick Date: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Pick Time: ${_selectedTime.format(context)}',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.access_time),
                    onPressed: () async {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (pickedTime != null) {
                        setState(() {
                          _selectedTime = pickedTime;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                setState(() {
                  _alarmTime = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  );
                  _alarmSetTime = DateTime.now();
                });
                Navigator.of(context).pop();
                _showAlarmSetNotification();
              },
              child: Text('Set Alarm'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showAlarmSetNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alarm set successfully for $_alarmTime'),
      ),
    );
  }

  void _triggerAlarm() {
    if (_isAlarmActive) return;
    setState(() {
      _isAlarmActive = true;
      _alarmLogs.add({
        'Set at': DateFormat('yyyy/MM/dd HH:mm:ss').format(_alarmSetTime!),
        'Executed': 'Yes',
      });
    });
    _startStrongVibration();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlarmRingingPage(
          onStop: () {
            setState(() {
              _isAlarmActive = false;
              _vibrationTimer?.cancel();
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _startStrongVibration() {
    Vibration.vibrate(
      pattern: [500, 1000, 500, 1000, 500, 1000, 500, 1000],
      intensities: [255, 255, 255, 255, 255, 255, 255, 255],
    );
  }

  void _viewAlarmLog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alarm Log'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _alarmLogs.map((log) {
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 8.0),
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Set at: ${log['Set at']}',
                              style: TextStyle(fontSize: 16.0),
                            ),
                            Text(
                              'Executed: ${log['Executed']}',
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          Navigator.pop(context);
                          _editAlarm(log);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _editAlarm(Map<String, dynamic> log) {
    DateTime alarmSetDate =
        DateFormat('yyyy/MM/dd').parse(log['Set at']!.split(' ')[0]);
    TimeOfDay alarmSetTime = TimeOfDay(
      hour: int.parse(log['Set at']!.split(' ')[1].split(':')[0]),
      minute: int.parse(log['Set at']!.split(' ')[1].split(':')[1]),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Alarm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Select Date: ${DateFormat('yyyy/MM/dd').format(alarmSetDate)}',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: alarmSetDate,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          alarmSetDate = pickedDate;
                        });
                      }
                    },
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Select Time: ${alarmSetTime.format(context)}',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.access_time),
                    onPressed: () async {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: alarmSetTime,
                      );
                      if (pickedTime != null) {
                        setState(() {
                          alarmSetTime = pickedTime;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                setState(() {
                  _alarmTime = DateTime(
                    alarmSetDate.year,
                    alarmSetDate.month,
                    alarmSetDate.day,
                    alarmSetTime.hour,
                    alarmSetTime.minute,
                  );
                  _alarmSetTime = DateTime.now();
                });
                Navigator.of(context).pop();
                _showAlarmSetNotification();
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Current time: $_currentTime",
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _setAlarm,
              child: Text('Set Alarm'),
            ),
            ElevatedButton(
              onPressed: _viewAlarmLog,
              child: Text('View Alarm Log'),
            ),
          ],
        ),
      ),
    );
  }
}

class AlarmRingingPage extends StatelessWidget {
  final VoidCallback onStop;

  AlarmRingingPage({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'IT IS TIME TO WAKE UP',
              style: TextStyle(
                fontSize: 24.0,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onStop,
              child: Text('STOP'),
            ),
          ],
        ),
      ),
    );
  }
}
