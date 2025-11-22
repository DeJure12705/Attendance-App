import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({Key? key}) : super(key: key);

  @override
  _TodayScreenState createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  double screenHeight = 0;
  double screenWidth = 0;
  Color primary = const Color.fromARGB(252, 47, 145, 42);
  String? _username; // added
  String checkIn = "--/--";
  String checkOut = "--/--";
  @override
  void initState() {
    super.initState();
    _loadUsername(); // added
    _getRecord();
  }

  Future<void> _loadUsername() async {
    // Prefer the static value already set after login/auth check.
    if (User.username.trim().isNotEmpty) {
      setState(() => _username = User.username.trim());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    // Login stored under 'studentId'
    final id = prefs.getString('studentId') ?? '';
    setState(() {
      _username = id;
      User.username = id; // keep in sync
    });
  }

  void _getRecord() async {
    final dateId = DateFormat('dd MMMM yyyy').format(DateTime.now());
    try {
      final studentQuery = await FirebaseFirestore.instance
          .collection("Student")
          .where('id', isEqualTo: User.username.trim())
          .limit(1)
          .get();
      if (studentQuery.docs.isEmpty) {
        setState(() {
          checkIn = "--/--";
          checkOut = "--/--";
        });
        return;
      }
      final studentDocId = studentQuery.docs.first.id;
      final recordRef = FirebaseFirestore.instance
          .collection("Student")
          .doc(studentDocId)
          .collection("Record")
          .doc(dateId);
      final recordSnap = await recordRef.get();
      if (!recordSnap.exists) {
        setState(() {
          checkIn = "--/--";
          checkOut = "--/--";
        });
        return;
      }
      final data = recordSnap.data() as Map<String, dynamic>;
      setState(() {
        checkIn = (data['checkIn'] ?? "--/--").toString();
        checkOut = (data['checkOut'] ?? "--/--").toString();
      });
    } catch (e) {
      setState(() {
        checkIn = "--/--";
        checkOut = "--/--";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight / 15),
                Text(
                  "Welcome",
                  style: TextStyle(
                    color: Colors.black54,
                    fontFamily: "NexaRegular",
                    fontSize: screenWidth / 20,
                  ),
                ),
                SizedBox(height: 16),

                Container(
                  alignment: Alignment.centerLeft,

                  child: Text(
                    "Student ${_username ?? ''}", // changed
                    style: TextStyle(
                      fontFamily: "NexaBold",
                      fontSize: screenWidth / 18,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(top: 32),
              child: Text(
                "Today's Status",
                style: TextStyle(
                  fontFamily: "NexaBold",
                  fontSize: screenWidth / 18,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 32),
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  ),
                ],
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Check In",
                            style: TextStyle(
                              fontFamily: "NexaRegular",
                              fontSize: screenWidth / 20,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            checkIn,
                            style: TextStyle(
                              fontFamily: "NexaBold",
                              fontSize: screenWidth / 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Check Out",
                            style: TextStyle(
                              fontFamily: "NexaRegular",
                              fontSize: screenWidth / 20,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            checkOut,
                            style: TextStyle(
                              fontFamily: "NexaBold",
                              fontSize: screenWidth / 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  text: DateTime.now().day.toString(),
                  style: TextStyle(
                    color: primary,
                    fontSize: screenWidth / 18,
                    fontFamily: "NexaBold",
                  ),
                  children: [
                    TextSpan(
                      text: DateFormat(' MMMM yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth / 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                return Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DateFormat('hh:mm:ss a').format(DateTime.now()),
                    style: TextStyle(
                      fontFamily: "NexaRegular",
                      fontSize: screenWidth / 20,
                      color: Colors.black54,
                    ),
                  ),
                );
              },
            ),
            checkOut == "--/--"
                ? Builder(
                    builder: (context) {
                      final GlobalKey<SlideActionState> key = GlobalKey();
                      return SlideAction(
                        text: checkIn == "--/--"
                            ? "Slide to Check In"
                            : "Slide to Check Out",
                        textStyle: TextStyle(
                          color: Colors.black54,
                          fontSize: screenWidth / 20,
                          fontFamily: "NexaRegular",
                        ),
                        outerColor: Colors.white,
                        innerColor: primary,
                        key: key,
                        onSubmit: () async {
                          Timer(const Duration(seconds: 1), () {
                            key.currentState?.reset();
                          });

                          final now = DateTime.now();
                          final dateId = DateFormat('dd MMMM yyyy').format(now);
                          final timeStr = DateFormat('hh:mm').format(now);
                          try {
                            final studentQuery = await FirebaseFirestore
                                .instance
                                .collection("Student")
                                .where('id', isEqualTo: User.username.trim())
                                .limit(1)
                                .get();
                            if (studentQuery.docs.isEmpty) return; // no student
                            final studentDocId = studentQuery.docs.first.id;
                            final recordRef = FirebaseFirestore.instance
                                .collection("Student")
                                .doc(studentDocId)
                                .collection("Record")
                                .doc(dateId);
                            final recordSnap = await recordRef.get();

                            if (checkIn == "--/--") {
                              // First slide -> create or set checkIn
                              await recordRef.set({
                                'checkIn': timeStr,
                                'checkOut': "--/--",
                              }, SetOptions(merge: true));
                              setState(() {
                                checkIn = timeStr;
                              });
                            } else if (checkOut == "--/--") {
                              // Second slide -> set checkOut
                              if (!recordSnap.exists) {
                                // If somehow missing, create with existing checkIn from state
                                await recordRef.set({
                                  'checkIn': checkIn,
                                  'checkOut': timeStr,
                                });
                              } else {
                                await recordRef.update({'checkOut': timeStr});
                              }
                              setState(() {
                                checkOut = timeStr;
                              });
                            }
                          } catch (e) {
                            // Optionally show a snackbar; keeping silent for now.
                          }
                        },
                      );
                    },
                  )
                : Container(
                    margin: const EdgeInsets.only(top: 32),
                    child: Text(
                      "You completed this day!",
                      style: TextStyle(
                        fontFamily: "NexaRegular",
                        fontSize: screenWidth / 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
