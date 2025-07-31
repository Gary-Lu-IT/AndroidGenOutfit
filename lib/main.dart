import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart'as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter 測試首頁'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String _currentTime='';
  Timer? _timer;
  Position? _currentPosition;
  String _locationMessage= "正在獲取位置...";
  String _cityInfo = "";

  @override
  void initState() {
    super.initState();
    _updateTime(); // 初始化時先取得一次時間
    _getLocationAndAdminAreaOSM(); //
    // 設定一個每秒觸發一次的計時器來更新時間
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  Future<void> _getLocationAndAdminAreaOSM() async {
    setState(() {
      _locationMessage = "正在獲取位置權限與座標...";
      _cityInfo = ""; // 重置城市資訊
    });

    bool serviceEnabled;
    LocationPermission permission;

    // 1. 檢查位置服務是否啟用 (與之前相同)
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() { _locationMessage = '位置服務已禁用。'; });
      return;
    }

    // 2. 檢查並請求位置權限 (與之前相同)
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() { _locationMessage = '位置權限被拒絕。'; });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() { _locationMessage = '位置權限被永久拒絕。'; });
      return;
    }

    // 3. 獲取目前位置 (經緯度)
    setState(() { _locationMessage = "正在獲取經緯度..."; });
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        _currentPosition = position;
        _locationMessage = '緯度: ${position.latitude.toStringAsFixed(4)}, 經度: ${position.longitude.toStringAsFixed(4)}';
      });

      // 4. 使用 OSM Nominatim 進行反向地理編碼
      setState(() { _locationMessage += "\n正在透過 OSM 轉換為地名..."; });

      final adminAreaData = await getAdminAreaFromCoordinatesOSM(position.latitude, position.longitude);

      if (adminAreaData != null && adminAreaData['administrativeArea'] != null && adminAreaData['administrativeArea']!.isNotEmpty) {
        String adminArea = adminAreaData['administrativeArea']!;
        String locality = adminAreaData['locality'] ?? "";
        String sublocality = adminAreaData['sublocality'] ?? "";
        setState(() {
          _cityInfo = "$adminArea $locality $sublocality".trim();
          _locationMessage = "目前位置 (OSM): $_cityInfo";
        });
      } else {
        setState(() {
          _cityInfo = "無法從 OSM 獲取地名";
          _locationMessage += "\n無法透過 OSM 將座標轉換為地名。";
        });
      }

    } catch (e) {
      print("獲取經緯度或 OSM 地名時發生錯誤: $e");
      setState(() {
        _locationMessage = '處理位置資訊時出錯: $e';
      });
    }
  }

  Future<Map<String, String>?> getAdminAreaFromCoordinatesOSM(double lat, double lon) async {
    // Nominatim API 端點
    // zoom=10 大約是城市級別，您可以調整或移除 zoom 參數以獲得不同詳細程度
    // addressdetails=1 可以獲取更詳細的地址組件
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&accept-language=zh-TW&addressdetails=1&zoom=10');

    print('正在請求 Nominatim API: $url'); // 打印請求的 URL 方便調試

    try {
      final response = await http.get(
        url,
        headers: {
          // Nominatim 要求提供有效的 User-Agent，通常是您的應用程式名稱或一個描述
          // 雖然不總是嚴格執行，但最好加上
          'User-Agent': 'YourAppName/1.0 (your.app.bundle.id; your@email.com)',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Nominatim API 回應: $data'); // 打印完整回應方便調試

        if (data != null && data['address'] != null) {
          final address = data['address'];
          String city = address['city'] ??
              address['state'] ?? // 有些地區 'state' 可能更接近縣市
              address['county'] ?? // 縣
              '';
          String district = address['suburb'] ?? // 郊區/更細的區域
              address['town'] ??
              address['village'] ??
              '';

          // 針對台灣，'state' 或 'county' 可能是直轄市/縣市
          // 'city' 在 Nominatim 中對於台灣可能指較大的市區，或有時是 'county' 的一部分
          // 您需要根據實際返回的 address 組件來調整提取邏輯
          // 例如，如果 'state' 是 "臺灣省"，那您可能需要看 'county' 或 'city'
          // 如果 'state' 直接是 "臺北市"，那它就是您要的

          // 為了簡化，我們先嘗試組合常見的欄位
          String administrativeArea = address['state'] ?? address['county'] ?? address['city'] ?? '未知地區';
          String localityInfo = address['city'] ?? address['town'] ?? address['suburb'] ?? ''; // 更細一級，如果有的話
          String sublocalityInfo = address['town'] ?? ''; // 最細一級，如果有的話

          print('OSM 提取 - 行政區: $administrativeArea, 地區: $localityInfo');
          return {'administrativeArea': administrativeArea, 'locality': localityInfo,'sublocality':sublocalityInfo};
        } else {
          print('Nominatim API 錯誤: 回應中沒有 address 資訊或 data 為 null');
          return null;
        }
      } else {
        print('Nominatim API HTTP 錯誤: ${response.statusCode}');
        print('Nominatim API 錯誤內容: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('呼叫 Nominatim API 時發生錯誤: $e');
      print('堆疊追蹤: $stackTrace');
      return null;
    }
  }

  void _updateTime() {
    // 獲取當前時間並使用 intl 套件格式化為 HH:mm:ss (24小時制)
    final String formattedTime = DateFormat('yyyy/MM/dd HH:mm:ss').format(DateTime.now());
    if (mounted) { // 檢查 widget 是否還在 widget tree 中
      setState(() {
        _currentTime = formattedTime;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // 當 widget 被移除時，取消計時器
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Column( // 使用 Column 來垂直排列標題和時間
          crossAxisAlignment: CrossAxisAlignment.start, // 讓文字靠左對齊
          children: [
            Text(widget.title),
            Text(
              _currentTime, // 顯示目前時間
              style: const TextStyle(fontSize: 16.0), // 您可以自訂時間的樣式
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('按「+」鈕次數:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(_locationMessage),
            if (_currentPosition != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text('經度: ${_currentPosition!.longitude}'),
                    Text('緯度: ${_currentPosition!.latitude}'),
                    Text('精確度: ${_currentPosition!.accuracy} 米'),
                    //Text('時間戳: ${_currentPosition!.timestamp!.toString()}'),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getLocationAndAdminAreaOSM, // 添加一個按鈕手動觸發位置更新
              child: const Text('重新獲取位置'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
