import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.width,
    this.height = 50,
    this.borderRadius = 12,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.padding,
    this.boxShadow,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultBackgroundColor = isOutlined 
        ? Colors.transparent 
        : backgroundColor ?? Colors.pink;
    final defaultTextColor = isOutlined 
        ? borderColor ?? Colors.pink 
        : textColor ?? Colors.white;
    final defaultBorderColor = borderColor ?? (isOutlined ? Colors.pink : Colors.transparent);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? (isOutlined ? null : [
          BoxShadow(
            color: (backgroundColor ?? Colors.pink).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ]),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: gradient != null ? Colors.transparent : defaultBackgroundColor,
          foregroundColor: defaultTextColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(
            color: defaultBorderColor,
            width: isOutlined ? 2 : 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: defaultTextColor,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: fontSize + 2,
                      color: defaultTextColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      color: defaultTextColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Predefined button styles
class CustomButtonStyles {
  // Primary button (Pink)
  static CustomButton primary({
    required String text,
    required VoidCallback? onPressed,
    double? width,
    double? height,
    bool isLoading = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      width: width,
      height: height,
      backgroundColor: Colors.pink,
      textColor: Colors.white,
      isLoading: isLoading,
      icon: icon,
    );
  }

  // Secondary button (Outlined)
  static CustomButton secondary({
    required String text,
    required VoidCallback? onPressed,
    double? width,
    double? height,
    bool isLoading = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      width: width,
      height: height,
      isOutlined: true,
      borderColor: Colors.pink,
      textColor: Colors.pink,
      isLoading: isLoading,
      icon: icon,
    );
  }

  // Success button (Green)
  static CustomButton success({
    required String text,
    required VoidCallback? onPressed,
    double? width,
    double? height,
    bool isLoading = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      width: width,
      height: height,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      isLoading: isLoading,
      icon: icon,
    );
  }

  // Danger button (Red)
  static CustomButton danger({
    required String text,
    required VoidCallback? onPressed,
    double? width,
    double? height,
    bool isLoading = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      width: width,
      height: height,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      isLoading: isLoading,
      icon: icon,
    );
  }

  // Gradient button
  static CustomButton gradient({
    required String text,
    required VoidCallback? onPressed,
    double? width,
    double? height,
    bool isLoading = false,
    IconData? icon,
    List<Color>? gradientColors,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      width: width,
      height: height,
      gradient: LinearGradient(
        colors: gradientColors ?? [Colors.pink, Colors.red.shade400],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
      isLoading: isLoading,
      icon: icon,
    );
  }

  // Social button (for social media login)
  static CustomButton social({
    required String text,
    required VoidCallback? onPressed,
    required IconData icon,
    required Color backgroundColor,
    double? width,
    double? height,
    bool isLoading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      icon: icon,
      isLoading: isLoading,
    );
  }

  // Floating action button style
  static Widget floating({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? iconColor,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.pink,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? Colors.pink).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }

  // Small button
  static CustomButton small({
    required String text,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? textColor,
    bool isOutlined = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      height: 36,
      fontSize: 14,
      backgroundColor: backgroundColor ?? Colors.pink,
      textColor: textColor ?? Colors.white,
      isOutlined: isOutlined,
      borderRadius: 8,
      icon: icon,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  // Large button
  static CustomButton large({
    required String text,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? textColor,
    bool isLoading = false,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      height: 60,
      fontSize: 18,
      backgroundColor: backgroundColor ?? Colors.pink,
      textColor: textColor ?? Colors.white,
      isLoading: isLoading,
      icon: icon,
      borderRadius: 16,
    );
  }
}