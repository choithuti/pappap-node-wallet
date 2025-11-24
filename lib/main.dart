import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PappapWallet());

class PappapWallet extends StatelessWidget {
  const PappapWallet({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pappap Node Wallet',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Roboto',
      ),
      home: const WalletHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WalletHome extends StatefulWidget {
  const WalletHome({super.key});

  @override
  State<WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome> {
  String status = "Đang khởi động node...";
  String balance = "0";
  String neurons = "0";
  String nodeId = "Chưa kết nối";
  final FlutterTts tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _checkNodeStatus();
  }

  Future<void> _loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('node_id') ?? "VIETNAM_NODE_${DateTime.now().millisecondsSinceEpoch}";
    await prefs.setString('node_id', savedId);
    setState(() => nodeId = savedId);
  }

  Future<void> _checkNodeStatus() async {
    try {
      final response = await http.get(Uri.parse("http://127.0.0.1:8080/api/status")).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          status = "NODE ĐÃ SỐNG! Kết nối Genesis Việt Nam";
          neurons = data["neurons"]?.toString() ?? "112384";
          balance = "10500128764.42"; // Genesis balance
        });
        _speak("Xin chào! Pappap AI Chain SNN đã sẵn sàng. Bạn đang sở hữu ${data["neurons"]} nơ-ron sống!");
      }
    } catch (e) {
      setState(() => status = "Node chưa chạy – nhấn Start Node");
    }
  }

  Future<void> _speak(String text) async {
    await tts.setLanguage("vi-VN");
    await tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pappap Node Wallet"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Image.asset("assets/logo.png", height: 100),
                    const SizedBox(height: 20),
                    Text("Node ID: $nodeId", style: const TextStyle(fontSize: 16)),
                    Text("Trạng thái: $status", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Neurons: $neurons", style: const TextStyle(fontSize: 24, color: Colors.green)),
                    Text("Balance: $balance \$PAPPAP", style: const TextStyle(fontSize: 20, color: Colors.amber)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
              child: const Text("Chat với Pappap AI (Tiếng Việt + Giọng nói)"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkNodeStatus,
              child: const Text("Kiểm tra Node"),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final messages = <Map<String, String>>[];
  final tts = FlutterTts();

  Future<void> _sendPrompt(String prompt) async {
    setState(() => messages.add({"role": "user", "content": prompt}));

    try {
      final res = await http.post(
        Uri.parse("http://127.0.0.1:8080/api/prompt"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"prompt": prompt}),
      );
      final data = jsonDecode(res.body);
      final response = data["response"] ?? "Không có phản hồi";
      final ttsText = data["tts"]?.split(",").length == 2 ? data["tts"] : null;

      setState(() => messages.add({"role": "ai", "content": response}));

      if (ttsText != null) {
        await tts.setLanguage("vi-VN");
        await tts.speak(response);
      }
    } catch (e) {
      setState(() => messages.add({"role": "error", "content": "Lỗi kết nối node"}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chat với Pappap AI")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final msg = messages[i];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg["content"]!,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: "Nhập tin nhắn..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      _sendPrompt(controller.text);
                      controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
