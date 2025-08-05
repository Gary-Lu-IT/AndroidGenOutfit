import 'dart:async';
import 'dart:convert';
//import 'dart:nativewrappers/_internal/vm/lib/typed_data_patch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:intl/intl.dart';
//import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart'as http;
import 'AnalyzedImage.dart';
import 'Azure_API.dart';
void main() {
  //runApp(const MyApp());
  runApp( OutfitSimulatorApp());
}

Future<Map<String, dynamic>?> analyzeImageFromAsset(String assetPath) async {
  final String endpoint = Azure_API.CVUrlAPI; // 替換為您的 Endpoint
  final String apiKey = Azure_API.CVUrlKey;       // 替換為您的 Key

  // 根據您使用的 API 版本調整 URL 和參數
  // 示例使用 v3.2
  final String apiUrl = "$endpoint/vision/v3.2/analyze?visualFeatures=Objects,Tags&language=en";
  // 或者 Image Analysis 4.0 (preview)
  // final String apiUrl = "$endpoint/computervision/imageanalysis:analyze?api-version=2023-02-01-preview&features=objects,tags&language=en";


  try {
    // 從 assets 讀取圖片數據
    final ByteData imageData = await rootBundle.load(assetPath);
    final List<int> bytes = imageData.buffer.asUint8List();

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Azure AI Vision API Error: ${response.statusCode}');
      debugPrint('Response: ${response.body}');
      return null;
    }
  } catch (e) {
    debugPrint('Error calling Azure AI Vision API: $e');
    return null;
  }
}

// 如何使用：
void processImages() async {
  List<String> imagePaths = [
    'assets/person/person_fg2.png',
    'assets/shirts/shirt0001.png',
    'assets/pants/pants0001.png',
  ];

  for (String path in imagePaths) {
    debugPrint("Analyzing: $path");
    Map<String, dynamic>? analysisResult = await analyzeImageFromAsset(path);

    if (analysisResult != null) {
      // 解析 analysisResult 來獲取物件邊界框和標籤
      // 例如，獲取物件：
      if (analysisResult['objects'] != null) {
        List<dynamic> objects = analysisResult['objects'] as List<dynamic>;
        for (var obj in objects) {
          String objectName = obj['object'] as String;
          Map<String, dynamic> rectangle = obj['rectangle'] as Map<String, dynamic>;
          double x = (rectangle['x'] as num).toDouble();
          double y = (rectangle['y'] as num).toDouble();
          double w = (rectangle['w'] as num).toDouble();
          double h = (rectangle['h'] as num).toDouble();
          double confidence = (obj['confidence'] as num).toDouble();

          debugPrint('  Detected: $objectName at [$x, $y, $w, $h] with confidence $confidence');

          // 根據 objectName 和 rectangle 計算您需要的錨點
          // 例如，如果 objectName 是 "person" 或 "shirt"
          double centerX = x + w / 2;
          double centerY = y + h / 2;
          debugPrint('    Center: ($centerX, $centerY)');
          // ... 更多基於 rectangle 的推斷計算
        }
      }
      // 獲取標籤
      if (analysisResult['tags'] != null) {
        List<dynamic> tags = analysisResult['tags'] as List<dynamic>;
        for (var tag in tags) {
          debugPrint('  Tag: ${tag['name']} (confidence: ${tag['confidence']})');
        }
      }
    }
    debugPrint("-" * 20);
  }
}

class OutfitSimulator extends StatefulWidget {
  @override
  _OutfitSimulatorState createState() => _OutfitSimulatorState();
}

class _OutfitSimulatorState extends State<OutfitSimulator> {
  // 預設人物模型 - 也需要分析
  final AnalyzedImage _personModel = AnalyzedImage('assets/person/person_fg.png'); // 您的預設人物圖路徑

  // 預設選擇的衣物圖片路徑 - 現在是 AnalyzedImage 對象
  AnalyzedImage? _selectedShirtModel;
  AnalyzedImage? _selectedPantsModel;

  // 衣物選項列表 - 現在是 List<AnalyzedImage>
  final List<AnalyzedImage> _shirtOptions = [
    AnalyzedImage('assets/shirts/shirt0001.png'),
    AnalyzedImage('assets/shirts/shirt0002.png'),
    // 添加更多上衣圖片路徑
  ];

  final List<AnalyzedImage> _pantsOptions = [
    AnalyzedImage('assets/pants/pants0001.png'),
    // 添加更多褲子圖片路徑
  ];

  bool _isLoadingAnalysis = true; // 用於顯示加載指示器

  @override
  void initState() {
    super.initState();
    _analyzeAllAssets();
  }
  Future<void> _analyzeAllAssets() async {
    setState(() {
      _isLoadingAnalysis = true;
    });

    // 分析人物模型
    Map<String, dynamic>? personAnalysis = await analyzeImageFromAsset(_personModel.assetPath);
    _personModel.updateWithAnalysis(personAnalysis, objectType: "person");

    // 分析所有上衣選項
    for (var shirtModel in _shirtOptions) {
      Map<String, dynamic>? shirtAnalysis = await analyzeImageFromAsset(shirtModel.assetPath);
      shirtModel.updateWithAnalysis(shirtAnalysis, objectType: "shirt");
    }
    // 預設選中第一個已分析的上衣
    if (_shirtOptions.isNotEmpty && _shirtOptions.first.boundingBox != null) {
      _selectedShirtModel = _shirtOptions.first;
    }


    // 分析所有褲子選項
    for (var pantsModel in _pantsOptions) {
      Map<String, dynamic>? pantsAnalysis = await analyzeImageFromAsset(pantsModel.assetPath);
      pantsModel.updateWithAnalysis(pantsAnalysis, objectType: "pants");
    }
    // 預設選中第一個已分析的褲子
    if (_pantsOptions.isNotEmpty && _pantsOptions.first.boundingBox != null) {
      _selectedPantsModel = _pantsOptions.first;
    }


    setState(() {
      _isLoadingAnalysis = false;
    });
  }

  void _selectShirt(AnalyzedImage shirt) {
    setState(() {
      _selectedShirtModel = shirt;
    });
  }

  void _selectPants(AnalyzedImage pants) {
    setState(() {
      _selectedPantsModel = pants;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAnalysis) {
      return Scaffold(
        appBar: AppBar(title: Text('穿搭模擬器')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // --- 動態計算位置和尺寸 ---
    Positioned? shirtLayer;
    Positioned? pantsLayer;

    // 確保人物模型和其參考錨點已加載
    if (_personModel.boundingBox != null &&
        _personModel.personShoulderCenter != null &&
        _personModel.personWaistCenter != null &&
        _personModel.personReferenceWidth != null) {

      final personCenterX = _personModel.personShoulderCenter!.dx; // 假設人物是居中的

      // --- 上衣圖層計算 ---
      if (_selectedShirtModel != null &&
          _selectedShirtModel!.boundingBox != null &&
          _selectedShirtModel!.clothingAnchor != null &&
          _selectedShirtModel!.clothingReferenceWidth != null &&
          _selectedShirtModel!.clothingOriginalHeight != null) {

        final shirt = _selectedShirtModel!;
        final personShoulderY = _personModel.personShoulderCenter!.dy;
        final personRefWidth = _personModel.personReferenceWidth!;

        // 1. 縮放比例 (基於人物參考寬度和上衣參考寬度)
        //    確保 clothingReferenceWidth 不為0，避免除零錯誤
        double scaleFactorShirt = (shirt.clothingReferenceWidth! > 0)
            ? (personRefWidth * 0.8) / shirt.clothingReferenceWidth! // 0.8 作為微調比例，讓衣服比人物略窄一點
            : 1.0;

        // 2. 縮放後的上衣尺寸
        double scaledShirtWidth = shirt.clothingReferenceWidth! * scaleFactorShirt;
        double scaledShirtHeight = shirt.clothingOriginalHeight! * scaleFactorShirt;

        // 3. 計算 Positioned 的 top 和 left
        //    目標：將上衣的 clothingAnchor (例如領口中心) 對齊人物的 personShoulderCenter
        //    shirt.clothingAnchor.x 是相對於其原始圖片左上角的
        //    縮放後，這個錨點在縮放後圖片中的 X 座標也按比例變化 (shirt.clothingAnchor!.dx * scaleFactorShirt)
        //    (scaledShirtWidth / 2) 是為了將衣物中心對齊人物中心
        double shirtTop = personShoulderY - (shirt.clothingAnchor!.dy * scaleFactorShirt)
            + 5; // 微調值：向上移動一點，您可以調整這個值
        double shirtLeft = personCenterX - (scaledShirtWidth / 2)
            - (shirt.clothingAnchor!.dx * scaleFactorShirt - shirt.clothingReferenceWidth!/2 * scaleFactorShirt) ; // 微調值：使衣物中心對齊


        shirtLayer = Positioned(
          top: shirtTop,
          left: shirtLeft,
          width: scaledShirtWidth,
          height: scaledShirtHeight,
          child: Image.asset(
            shirt.assetPath,
            fit: BoxFit.fill, // 因為我們計算了精確的縮放尺寸
          ),
        );
        debugPrint("Shirt Layer: top=$shirtTop, left=$shirtLeft, width=$scaledShirtWidth, height=$scaledShirtHeight, path=${shirt.assetPath}");
      }

      // --- 褲子圖層計算 ---
      if (_selectedPantsModel != null &&
          _selectedPantsModel!.boundingBox != null &&
          _selectedPantsModel!.clothingAnchor != null &&
          _selectedPantsModel!.clothingReferenceWidth != null &&
          _selectedPantsModel!.clothingOriginalHeight != null) {

        final pants = _selectedPantsModel!;
        final personWaistY = _personModel.personWaistCenter!.dy;
        final personRefWidth = _personModel.personReferenceWidth!; // 可以用同一個或單獨的腰部參考寬度

        double scaleFactorPants = (pants.clothingReferenceWidth! > 0)
            ? (personRefWidth * 0.75) / pants.clothingReferenceWidth! // 0.75 作為微調
            : 1.0;

        double scaledPantsWidth = pants.clothingReferenceWidth! * scaleFactorPants;
        double scaledPantsHeight = pants.clothingOriginalHeight! * scaleFactorPants;

        double pantsTop = personWaistY - (pants.clothingAnchor!.dy * scaleFactorPants)
            - 5; // 微調值：向下移動一點
        double pantsLeft = personCenterX - (scaledPantsWidth / 2)
            - (pants.clothingAnchor!.dx * scaleFactorPants - pants.clothingReferenceWidth!/2 * scaleFactorPants);


        pantsLayer = Positioned(
          top: pantsTop,
          left: pantsLeft,
          width: scaledPantsWidth,
          height: scaledPantsHeight,
          child: Image.asset(
            pants.assetPath,
            fit: BoxFit.fill,
          ),
        );
        debugPrint("Pants Layer: top=$pantsTop, left=$pantsLeft, width=$scaledPantsWidth, height=$scaledPantsHeight, path=${pants.assetPath}");
      }
    } else {
      debugPrint("Person model or its anchors are not yet loaded/analyzed.");
    }


    return Scaffold(
      appBar: AppBar(
        title: Text('穿搭模擬器'),
      ),
      body: Center(
        child: Container( // 可以給 Stack 一個固定大小或讓它自適應
          width: 300, // 示例：給一個固定寬度
          height: 500, // 示例：給一個固定高度
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)), // 方便調試邊界
          child: Stack(
            alignment: Alignment.topCenter, // 可以嘗試不同的 alignment
            children: <Widget>[
              // 底層：人物全身圖 (讓它填滿容器)
              Positioned.fill(
                child: Image.asset(
                  _personModel.assetPath,
                  fit: BoxFit.contain,
                ),
              ),

              // 中間層：選擇的上衣 (如果已計算)
              if (shirtLayer != null) shirtLayer,

              // 上層：選擇的褲子 (如果已計算)
              if (pantsLayer != null) pantsLayer,
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // ... (衣物選擇 UI，將傳遞 AnalyzedImage 而不是 String)
        // 例如 onTap: (index) {
        //   if (index == 0) {
        //     _showClothingSelectionDialog(context, '上衣', _shirtOptions, _selectShirt);
        //   } ...
        // }
        // (彈窗的實現也需要修改以處理 AnalyzedImage)
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: '選擇上衣'),
          BottomNavigationBarItem(icon: Icon(Icons.dry_cleaning), label: '選擇褲子'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            _showClothingSelectionDialog(context, '上衣', _shirtOptions, (item){
              _selectShirt(item); // item is AnalyzedImage
            });
          } else if (index == 1) {
            _showClothingSelectionDialog(context, '褲子', _pantsOptions, (item){
              _selectPants(item); // item is AnalyzedImage
            });
          }
        },
      ),
    );
  }

  // 修改後的衣物選擇彈窗
  void _showClothingSelectionDialog(
      BuildContext context,
      String title,
      List<AnalyzedImage> clothingItems, // 改為 AnalyzedImage
      Function(AnalyzedImage) onSelect) { // 回調參數改為 AnalyzedImage
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('選擇$title'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: List<Widget>.generate(clothingItems.length, (index) {
                final item = clothingItems[index];
                // 確保圖片在顯示前已經被分析，或者有一個預設的顯示方式
                // 這裡我們直接用 assetPath，因為縮圖本身不參與複雜定位
                return GestureDetector(
                  onTap: () {
                    if (item.boundingBox == null) {
                      // 可以提示用戶該圖片尚未分析完成或分析失敗
                      debugPrint("Warning: ${item.assetPath} has not been analyzed or analysis failed.");
                      // 或者在這裡觸發一次性分析
                      // analyzeImageFromAsset(item.assetPath).then((result) {
                      //   item.updateWithAnalysis(result, objectType: title == '上衣' ? 'shirt' : 'pants');
                      //   if (item.boundingBox != null) onSelect(item);
                      //   Navigator.of(context).pop();
                      // });
                      // return; // 阻止選擇未分析的
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item.assetPath} 正在分析中或分析失敗，請稍後重試。')),
                      );
                      return;
                    }
                    onSelect(item);
                    Navigator.of(context).pop();
                  },
                  child: Opacity( // 如果未分析，可以降低透明度
                    opacity: item.boundingBox != null ? 1.0 : 0.5,
                    child: Image.asset(
                      item.assetPath, // 彈窗中顯示原圖或縮圖
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('關閉'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}


// 如果想直接運行 OutfitSimulator，可以建立一個簡單的 App 包裝它
class OutfitSimulatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '穿搭模擬器',
      theme: ThemeData(
        primarySwatch: Colors.blue, // 您可以自訂主題
      ),
      home: OutfitSimulator(),
    );
  }
}