import 'package:flutter/material.dart';
import 'package:birdle/game.dart';
import 'package:birdle/external_process_manager.dart';
import 'package:birdle/external_process_manager_windows.dart';
import 'dart:io';
import 'dart:ui';

void main() async {
  // Đảm bảo Flutter binding được khởi tạo trước khi gọi logic không đồng bộ
  WidgetsFlutterBinding.ensureInitialized();

  // Auto-start Mock Service based on operating system
  if (Platform.isWindows) {
    await ExternalProcessManagerWindows.startWindowsService();
  } else {
    await ExternalProcessManager.startMockApi();
  }

  // Listen for terminal exit signals (Ctrl+C)
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) {
      ExternalProcessManager.stopMockApi();
      ExternalProcessManagerWindows.stopWindowsService();
      exit(0);
    });
  }

  // Catch Desktop app exit event (Close window button)
  AppLifecycleListener(
    onExitRequested: () async {
      ExternalProcessManager.stopMockApi();
      ExternalProcessManagerWindows.stopWindowsService();
      return AppExitResponse.exit;
    },
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đoán tên riêng',
      home: Scaffold(
        appBar: AppBar(
          title: Align(
            alignment: Alignment.centerLeft,
            child: Text('Đoán tên riêng (5 chữ cái)'),
          ),
        ),
        body: Center(child: GamePage()),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Game _game = Game();

  @override
  Widget build(BuildContext context) {
    final isGameOver = _game.didWin || _game.didLose;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        spacing: 5.0,
        children: [
          for (var guess in _game.guesses)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 5.0,
              children: [
                for (var letter in guess)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2.5,
                      vertical: 2.5,
                    ),
                    child: Tile(letter.char, letter.type),
                  ),
              ],
            ),
          if (isGameOver)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(
                    _game.didWin
                        ? '🎉 Chúc mừng! Bạn đã thắng!'
                        : '💀 Game Over! Đáp án là: ${_game.hiddenWord.toString().toUpperCase()}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _game.didWin ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _game.resetGame();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('CHƠI LẠI'),
                  ),
                ],
              ),
            )
          else
            GuessInput(
              onSubmitGuess: (String guess) {
                if (_game.isLegalGuess(guess)) {
                  setState(() {
                    _game.guess(guess);
                  });
                } else {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Hãy thử đoán một cái tên khác nhé (Tên 5 chữ cái có dấu)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: const Color.fromARGB(255, 255, 34, 34),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class Tile extends StatelessWidget {
  const Tile(this.letter, this.hitType, {super.key});

  final String letter;
  final HitType hitType;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.bounceIn,
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: switch (hitType) {
          HitType.hit => Colors.green,
          HitType.partial => Colors.yellow,
          HitType.miss => Colors.grey,
          _ => Colors.white,
        },
      ),
      child: Center(
        child: Text(
          letter.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class GuessInput extends StatefulWidget {
  const GuessInput({super.key, required this.onSubmitGuess});

  final void Function(String) onSubmitGuess;

  @override
  State<GuessInput> createState() => _GuessInputState();
}

class _GuessInputState extends State<GuessInput> {
  late TextEditingController _textEditingController;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    widget.onSubmitGuess(_textEditingController.text);
    _textEditingController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              maxLength: 5,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(35)),
                ),
              ),
              controller: _textEditingController,
              autofocus: true,
              focusNode: _focusNode,
              onSubmitted: (_) {
                _onSubmit();
              },
            ),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(Icons.arrow_circle_up),
          iconSize: 40,
          onPressed: _onSubmit,
        ),
      ],
    );
  }
}
