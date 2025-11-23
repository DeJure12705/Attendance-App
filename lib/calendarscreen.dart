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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select any date in the month',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
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
                  color: Colors.black54,
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
                      color: Colors.black54,
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
                        color: Colors.black54,
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
              const Text('Student not found.')
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
                    return const Text('No attendance records for this month.');
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
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
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Check In: ${r.checkIn}',
                                  style: TextStyle(
                                    fontFamily: 'NexaRegular',
                                    fontSize: screenWidth / 26,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Out: ${r.checkOut}',
                              style: TextStyle(
                                fontFamily: 'NexaRegular',
                                fontSize: screenWidth / 26,
                                color: Colors.black54,
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
