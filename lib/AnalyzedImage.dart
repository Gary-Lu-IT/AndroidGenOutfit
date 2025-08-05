// 在您的 main.dart 頂部或單獨的數據模型文件中

import 'dart:ui';

class AnalyzedImage {
  final String assetPath;
  Rect? boundingBox; // 從 Azure 獲取的原始邊界框 (x, y, w, h)
  Offset? personShoulderCenter; // 推斷的人物肩部中心
  Offset? personWaistCenter;    // 推斷的人物腰部中心
  double? personReferenceWidth; // 推斷的人物參考寬度 (例如，身體邊界框寬度)

  Offset? clothingAnchor;       // 推斷的衣物錨點 (例如，領口中心或腰部頂部中心)
  double? clothingReferenceWidth; // 衣物原始邊界框寬度
  double? clothingOriginalHeight; // 衣物原始邊界框高度

  AnalyzedImage(this.assetPath);

  // 方法：使用 Azure 分析結果更新此對象
  void updateWithAnalysis(Map<String, dynamic>? analysisResult, {String objectType = "person"}) {
    if (analysisResult == null || analysisResult['objects'] == null) return;

    List<dynamic> objects = analysisResult['objects'] as List<dynamic>;
    Map<String, dynamic>? targetObjectData;

    // 找到最相關的物件 (可以根據 confidence 或 objectType 進一步篩選)
    for (var obj in objects) {
      String detectedObjectName = (obj['object'] as String).toLowerCase();
      if (detectedObjectName.contains(objectType.toLowerCase()) ||
          (objectType == "shirt" && (detectedObjectName.contains("shirt") || detectedObjectName.contains("top") || detectedObjectName.contains("clothing"))) ||
          (objectType == "pants" && (detectedObjectName.contains("pants") || detectedObjectName.contains("trousers") || detectedObjectName.contains("clothing")))) {
        targetObjectData = obj as Map<String, dynamic>;
        break; // 暫時取第一個匹配的
      }
    }
    if (targetObjectData == null && objects.isNotEmpty) {
      // 如果沒有精確匹配，嘗試取第一個檢測到的物件 (作為備選方案)
      // targetObjectData = objects.first as Map<String, dynamic>;
      print("Warning: Could not find specific objectType '$objectType' for $assetPath. Inspect Azure results.");
      // 如果嚴格要求，這裡可以 return 或拋出錯誤
    }


    if (targetObjectData != null) {
      Map<String, dynamic> rectData = targetObjectData['rectangle'] as Map<String, dynamic>;
      double x = (rectData['x'] as num).toDouble();
      double y = (rectData['y'] as num).toDouble();
      double w = (rectData['w'] as num).toDouble();
      double h = (rectData['h'] as num).toDouble();
      boundingBox = Rect.fromLTWH(x, y, w, h);

      // --- 根據 boundingBox 推斷錨點和參考尺寸 ---
      // 這些推斷規則是示例，您需要根據實際效果仔細調整
      if (objectType == "person") {
        personShoulderCenter = Offset(x + w / 2, y + h * 0.20); // 假設肩膀在高度的20%
        personWaistCenter = Offset(x + w / 2, y + h * 0.52);    // 假設腰部在高度的52%
        personReferenceWidth = w;
        print("Analyzed Person: $assetPath, Box: $boundingBox, Shoulder: $personShoulderCenter, Waist: $personWaistCenter");
      } else if (objectType == "shirt") {
        clothingAnchor = Offset(x + w / 2, y); // 衣物頂部中心作為錨點
        clothingReferenceWidth = w;
        clothingOriginalHeight = h;
        print("Analyzed Shirt: $assetPath, Box: $boundingBox, Anchor: $clothingAnchor");
      } else if (objectType == "pants") {
        clothingAnchor = Offset(x + w / 2, y); // 衣物頂部中心作為錨點
        clothingReferenceWidth = w;
        clothingOriginalHeight = h;
        print("Analyzed Pants: $assetPath, Box: $boundingBox, Anchor: $clothingAnchor");
      }
    } else {
      print("Could not find relevant object in Azure analysis for $assetPath and type $objectType");
    }
  }
}