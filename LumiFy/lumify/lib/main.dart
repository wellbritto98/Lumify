import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';



void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUMIFY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      home: Scaffold(
        body: LEDAndPIRControl(),
      ),
    );
  }
}



class LEDAndPIRControl extends StatefulWidget {
  @override
  _LEDAndPIRControlState createState() => _LEDAndPIRControlState();
}




class _LEDAndPIRControlState extends State<LEDAndPIRControl> {
  bool isLEDOn = false;
  bool isPIROn = true;
  late StreamSubscription _statusSubscription;
  String ip = "192.168.0.50"; // adicione a variável ip

  @override
  void initState() {
    super.initState();
    loadLastIPAddress();
    fetchStatus();
    startMonitoring();
  }

  Future<void> loadLastIPAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final lastIPAddress = prefs.getString('lastIPAddress');
    if (lastIPAddress != null) {
      setState(() {
        ip = lastIPAddress;
      });
    }
  }

  Future<void> fetchStatus() async {
    try {
      final ledResponse = await http.get(Uri.parse('http://$ip:8080/led/status'));
      final pirResponse = await http.get(Uri.parse('http://$ip:8080/pir/status'));

      setState(() {
        isPIROn = pirResponse.body == 'Ativado';
        if (!isPIROn) {
          isLEDOn = ledResponse.body == 'Ligado';
        } else {
          isLEDOn = false;
        }
      });
    } catch (e) {
      print('Erro ao buscar o status: $e');
    }
  }

  void startMonitoring() {
    _statusSubscription = Stream.periodic(Duration(seconds: 1)).listen((_) {
      fetchStatus();
    });
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    super.dispose();
  }


  void toggleLED() async {
    String url = isLEDOn ? 'http://$ip:8080/led/off' : 'http://$ip:8080/led/on';
    await http.get(Uri.parse(url));
    setState(() {
      isLEDOn = !isLEDOn;
    });
  }

  void togglePIR() async {
    String url = isPIROn ? 'http://$ip:8080/pir/off' : 'http://$ip:8080/pir/on';
    await http.get(Uri.parse(url));
    setState(() {
      isPIROn = !isPIROn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Text(
                'L  U  M  I  F  Y',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Vonique',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              top: 60,
              right: 20,
              child: IconButton(
                onPressed: () async {
                  String? newIP = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Conectar ao ESP8266"),
                        content: TextField(
                          decoration: InputDecoration(
                            hintText: "Digite o IP do ESP8266",
                          ),
                          onChanged: (value) {
                            ip = value;
                          },
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              prefs.setString('lastIPAddress', ip);
                              Navigator.pop(context, ip);
                            },
                            child: Text("Conectar"),
                          ),
                        ],
                      );
                    },
                  );
                  if (newIP != null) {
                    ip = newIP;
                    fetchStatus();
                  }
                },
                icon: Image.asset(
                  'assets/wifi_icon.png',
                  height: 40,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 100),
                  Text(
                    'LIGAR / DESLIGAR',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontFamily: 'ModernSans',
                    ),
                  ),
                  SizedBox(height: 10),
                  Switch(
                    value: isLEDOn,
                    onChanged: (value) {
                      toggleLED();
                    },
                  ),
                  SizedBox(height: 20),
                  Text(
                    'SENSOR DE PRESENÇA',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontFamily: 'ModernSans',
                    ),
                  ),
                  SizedBox(height: 10),
                  Switch(
                    value: isPIROn,
                    onChanged: (value) {
                      togglePIR();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}