import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendanceapp/model/user.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  double screenHeight = 0;
  double screenWidth = 0;
  Color primary = const Color.fromARGB(252, 47, 145, 42);

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _studentDocId;
  bool _loadingStudent = true;

  @override
  void initState() {
    super.initState();
    _ensureStudentDocId();
  }

  Future<void> _ensureStudentDocId() async {
    final cached = User.id.trim();
    if (cached.isNotEmpty) {
      setState(() {
        _studentDocId = cached;
        _loadingStudent = false;
      });
      return;
    }
    try {
      final sid = User.studentId.trim();
      if (sid.isEmpty) {
        setState(() => _loadingStudent = false);
        return;
      }
      final query = await FirebaseFirestore.instance
          .collection('Student')
          .where('id', isEqualTo: sid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final docId = query.docs.first.id;
        setState(() {
          _studentDocId = docId;
          _loadingStudent = false;
        });
        User.id = docId; // cache globally
      } else {
        setState(() => _loadingStudent = false);
      }
    } catch (_) {
      setState(() => _loadingStudent = false);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Month'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    // Year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setDialogState(() {
                              selectedYear--;
                            });
                          },
                        ),
                        Text(
                          selectedYear.toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setDialogState(() {
                              selectedYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Month grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final isSelected =
                              selectedYear == _selectedMonth.year &&
                              month == _selectedMonth.month;
                          final monthName = DateFormat(
                            'MMM',
                          ).format(DateTime(2000, month));

                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedMonth = month;
                              });
                              setState(() {
                                _selectedMonth = DateTime(selectedYear, month);
                              });
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? primary
                                      : Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  monthName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(top: 32),
              child: Text(
                'My Attendance',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontFamily: 'NexaBold',
                  fontSize: screenWidth / 18,
                ),
              ),
            ),
            Stack(
              children: [
                Container(
                  alignment: Alignment.centerLeft,
                  margin: const EdgeInsets.only(top: 32),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontFamily: 'NexaBold',
                      fontSize: screenWidth / 18,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickMonth,
                  child: Container(
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.only(top: 32),
                    child: Text(
                      'Pick a Month',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontFamily: 'NexaBold',
                        fontSize: screenWidth / 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingStudent)
              const Center(child: CircularProgressIndicator())
            else if (_studentDocId == null || _studentDocId!.isEmpty)
              Text(
                'Student not found.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            else
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Student')
                    .doc(_studentDocId)
                    .collection('Record')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox();
                  }
                  final docs = snapshot.data!.docs;
                  // Convert and filter by selected month
                  final records = <_AttendanceRecord>[];
                  for (final d in docs) {
                    final id = d.id; // expected 'dd MMMM yyyy'
                    DateTime? date;
                    try {
                      date = DateFormat('dd MMMM yyyy').parse(id);
                    } catch (_) {
                      continue; // skip unparsable docs
                    }
                    if (date.year == _selectedMonth.year &&
                        date.month == _selectedMonth.month) {
                      final data = d.data() as Map<String, dynamic>;
                      records.add(
                        _AttendanceRecord(
                          date: date,
                          checkIn: (data['checkIn'] ?? '--/--').toString(),
                          checkOut: (data['checkOut'] ?? '--/--').toString(),
                        ),
                      );
                    }
                  }
                  records.sort((a, b) => a.date.compareTo(b.date));

                  if (records.isEmpty) {
                    return Text(
                      'No attendance records for this month.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final r = records[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withOpacity(0.26),
                              blurRadius: 10,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEE, dd MMM').format(r.date),
                                  style: TextStyle(
                                    fontFamily: 'NexaBold',
                                    fontSize: screenWidth / 22,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Check In: ${r.checkIn}',
                                  style: TextStyle(
                                    fontFamily: 'NexaRegular',
                                    fontSize: screenWidth / 26,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Out: ${r.checkOut}',
                              style: TextStyle(
                                fontFamily: 'NexaRegular',
                                fontSize: screenWidth / 26,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRecord {
  final DateTime date;
  final String checkIn;
  final String checkOut;
  _AttendanceRecord({
    required this.date,
    required this.checkIn,
    required this.checkOut,
  });
}
