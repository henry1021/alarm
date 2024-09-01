import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  tz.initializeTimeZones(); // Initialize time zones for timezone package
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
  List<Map<String, dynamic>> _alarmLogs = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _updateTime();
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Dispose the audio player
    super.dispose();
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
                      'Select Date: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
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
                      'Select Time: ${_selectedTime.format(context)}',
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

                  _alarmLogs.add({
                    'Set at': DateFormat('yyyy/MM/dd HH:mm:ss')
                        .format(_alarmSetTime!),
                    'Alarm Time':
                        DateFormat('yyyy/MM/dd HH:mm:ss').format(_alarmTime!),
                    'Executed': 'Not Executed',
                  });
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

  void _triggerAlarm() {
    if (_isAlarmActive) return;
    setState(() {
      _isAlarmActive = true;

      for (var log in _alarmLogs) {
        if (log['Alarm Time'] ==
            DateFormat('yyyy/MM/dd HH:mm:ss').format(_alarmTime!)) {
          log['Executed'] = 'Yes';
          break;
        }
      }
    });

    _startVibration();
    _playAlarmSound();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlarmRingingPage(
          onStop: () {
            setState(() {
              _isAlarmActive = false;
              _vibrationTimer?.cancel();
              _audioPlayer.stop();
            });
            _stopVibration();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showAlarmSetNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alarm set successfully for $_alarmTime'),
      ),
    );
  }

  void _startVibration() async {
    bool? canVibrate = await Vibration.hasVibrator();
    if (canVibrate == true) {
      Vibration.vibrate(
        pattern: [500, 1000, 500, 1000, 500, 1000, 500, 1000],
        intensities: [255, 255, 255, 255, 255, 255, 255, 255],
      );
    }
  }

  void _stopVibration() {
    Vibration.cancel();
  }

  void _playAlarmSound() async {
    // Ensure the audio file path is correct relative to your pubspec.yaml
    await _audioPlayer.setSource(AssetSource('sounds/alarm_sound.mp3'));
    await _audioPlayer.resume();
  }

  void _viewAlarmLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlarmLogPage(
          alarmLogs: _alarmLogs,
          onEdit: (log) {
            _editAlarm(log);
          },
          onDelete: (logsToDelete) {
            setState(() {
              _alarmLogs.removeWhere((log) => logsToDelete.contains(log));
            });
          },
        ),
      ),
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
                  log['Set at'] = DateFormat('yyyy/MM/dd HH:mm:ss').format(
                    DateTime(
                      alarmSetDate.year,
                      alarmSetDate.month,
                      alarmSetDate.day,
                      alarmSetTime.hour,
                      alarmSetTime.minute,
                    ),
                  );
                });
                Navigator.of(context).pop();
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
        title: Text('Alarm Home Page'),
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

class AlarmLogPage extends StatefulWidget {
  final List<Map<String, dynamic>> alarmLogs;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(List<Map<String, dynamic>>) onDelete;

  AlarmLogPage({
    required this.alarmLogs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  _AlarmLogPageState createState() => _AlarmLogPageState();
}

class _AlarmLogPageState extends State<AlarmLogPage> {
  List<Map<String, dynamic>> _selectedLogs = [];
  bool _isManagementMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alarm Log'),
        actions: [
          if (_isManagementMode)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    if (_selectedLogs.isNotEmpty) {
                      widget.onDelete(_selectedLogs);
                      setState(() {
                        _selectedLogs.clear();
                        _isManagementMode = false;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: () {
                    setState(() {
                      _isManagementMode = false;
                      _selectedLogs.clear();
                    });
                  },
                ),
              ],
            ),
          if (!_isManagementMode)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isManagementMode = !_isManagementMode;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: widget.alarmLogs.map((log) {
                return ListTile(
                  title: Column(
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
                  trailing: _isManagementMode
                      ? Checkbox(
                          value: _selectedLogs.contains(log),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedLogs.add(log);
                              } else {
                                _selectedLogs.remove(log);
                              }
                            });
                          },
                        )
                      : IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            widget.onEdit(log);
                          },
                        ),
                  onTap: _isManagementMode
                      ? null
                      : () {
                          widget.onEdit(log);
                        },
                );
              }).toList(),
            ),
          ),
          if (_isManagementMode)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: _selectAll,
                child: Text('Select All'),
              ),
            ),
        ],
      ),
    );
  }

  void _selectAll() {
    setState(() {
      _selectedLogs = List.from(widget.alarmLogs);
    });
  }
}
