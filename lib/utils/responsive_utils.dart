import 'package:flutter/material.dart';

class ResponsiveUtils {
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  
  // Initialize with the BuildContext
  static void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
  }
  
  // Get responsive width
  static double getWidth(double percentage) {
    return blockSizeHorizontal * percentage;
  }
  
  // Get responsive height
  static double getHeight(double percentage) {
    return blockSizeVertical * percentage;
  }
  
  // Font sizes
  static double getSmallFontSize() {
    return blockSizeHorizontal * 3.0;
  }
  
  static double getRegularFontSize() {
    return blockSizeHorizontal * 3.5;
  }
  
  static double getMediumFontSize() {
    return blockSizeHorizontal * 4.0;
  }
  
  static double getLargeFontSize() {
    return blockSizeHorizontal * 5.5;
  }
  
  // Padding and spacing
  static double getTinyPadding() {
    return blockSizeHorizontal * 1.0;
  }
  
  static double getSmallPadding() {
    return blockSizeHorizontal * 2.0;
  }
  
  static double getRegularPadding() {
    return blockSizeHorizontal * 3.0;
  }
  
  static double getMediumPadding() {
    return blockSizeHorizontal * 4.0;
  }
  
  static double getLargePadding() {
    return blockSizeHorizontal * 6.0;
  }
  
  // Icon sizes
  static double getSmallIconSize() {
    return blockSizeHorizontal * 4.0;
  }
  
  static double getRegularIconSize() {
    return blockSizeHorizontal * 5.0;
  }
  
  static double getLargeIconSize() {
    return blockSizeHorizontal * 7.0;
  }
  
  // Border radius
  static double getSmallRadius() {
    return blockSizeHorizontal * 2.0;
  }
  
  static double getRegularRadius() {
    return blockSizeHorizontal * 3.0;
  }
  
  static double getLargeRadius() {
    return blockSizeHorizontal * 4.0;
  }
  
  // QR Code size (keep this fixed for better scanning)
  static double getQRCodeSize() {
    return blockSizeHorizontal * 60.0;  // 60% of screen width
  }
} 