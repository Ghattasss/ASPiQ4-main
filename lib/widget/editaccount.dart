// editaccount.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myfinalpro/auth_services.dart';
import 'package:myfinalpro/widget/custom_profile_text_field.dart';
import 'package:myfinalpro/login/forgetPassword.dart'; // تأكد من أن اسم الملف صحيح
import 'package:shared_preferences/shared_preferences.dart';
// ١. استيراد ملف القائمة الجانبية للوصول إلى المفتاح ودالة التحديث
import 'package:myfinalpro/widget/side_bar_menu.dart.dart'; 


class EditAccountScreen extends StatefulWidget {
  const EditAccountScreen({super.key});

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _doctorIdController = TextEditingController();
  final TextEditingController _childDobController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(text: "************");

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _profileImageUrl = 'assets/images/placeholder.png';
  File? _selectedImageFile;
  String? _newlyUploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _doctorIdController.dispose();
    _childDobController.dispose();
    _usernameController.dispose();
    _phoneEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // دالة جلب البيانات من الـ API وتحديث القائمة الجانبية
  Future<void> _loadUserProfileData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('المستخدم غير مسجل الدخول');

      final result = await AuthService.getUserProfile(token);
      if (!mounted) return;

      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        final profileData = result['data'] as Map<String, dynamic>;
        
        final String childName = profileData['name_'] ?? profileData['name'] ?? '';
        final String imageUrl = profileData['image_'] ?? profileData['image_url'] ?? '';

        // ٢. تخزين البيانات فورًا في SharedPreferences لضمان تحديث القائمة دائمًا
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('child_name', childName);
        if (imageUrl.isNotEmpty) {
          await prefs.setString('child_image_url', imageUrl);
        }
        
        // ٣. استدعاء دالة التحديث في القائمة الجانبية مباشرة
        sideBarKey.currentState?.loadDataForDrawer();

        // باقي الكود لتعبئة الحقول وتنسيق التاريخ
        String rawBirthDate = profileData['birthDate'] ?? '';
        String formattedBirthDate = 'غير متوفر';
        if (rawBirthDate.isNotEmpty) {
           try {
              DateTime parsedDate = DateTime.parse(rawBirthDate);
              formattedBirthDate = "${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}";
           } catch(e) {
              formattedBirthDate = rawBirthDate;
           }
        }
        
        setState(() {
          _nameController.text = childName;
          _surnameController.text = profileData['surname'] ?? '';
          _doctorIdController.text = profileData['doctor_ID']?.toString() ?? '';
          _profileImageUrl = imageUrl;
          _usernameController.text = profileData['email'] ?? 'غير متوفر';
          _phoneEmailController.text = profileData['phone'] ?? 'غير متوفر';
          _childDobController.text = formattedBirthDate;
          _isLoading = false;
        });
      } else {
        throw Exception(result['message'] ?? 'فشل تحميل بيانات الملف الشخصي');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = "فشل تحميل البيانات: ${e.toString()}"; _isLoading = false; });
      }
    }
  }

  // دالة رفع الصورة وتحديث القائمة الجانبية فورًا
  Future<void> _pickAndUploadImage() async {
    if (_isSaving) return;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image == null) return;
      
      final fileToUpload = File(image.path);
      if (!mounted) return;
      setState(() { _selectedImageFile = fileToUpload; _isSaving = true; _errorMessage = null; });

      final newUrl = await AuthService.uploadImageToImgBB(fileToUpload);
      if (!mounted) return;

      if (newUrl != null) {
        // ٤. تخزين الرابط الجديد في SharedPreferences وتحديث القائمة فورًا
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('child_image_url', newUrl);
        sideBarKey.currentState?.loadDataForDrawer(); // <-- تحديث فوري للقائمة

        setState(() {
          _newlyUploadedImageUrl = newUrl;
          _profileImageUrl = newUrl;
          _selectedImageFile = null;
          _isSaving = false;
        });
        _showSnackBar("تم رفع الصورة بنجاح. اضغط حفظ لتأكيد باقي التغييرات.", isError: false);
      } else {
        throw Exception('فشل الحصول على رابط الصورة بعد الرفع');
      }
    } catch (e) {
      if (mounted) { setState(() { _errorMessage = "فشل رفع الصورة"; _isSaving = false; _selectedImageFile = null; }); }
    }
  }
  
  // دالة الحفظ
  Future<void> _saveProfileChanges() async {
    if (_isSaving || _isLoading) return;
    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('User not authenticated');

      final String name = _nameController.text.trim();
      final String surname = _surnameController.text.trim();
      final String doctorIdString = _doctorIdController.text.trim();
      final int? doctorId = doctorIdString.isNotEmpty ? int.tryParse(doctorIdString) : null;

      if (name.isEmpty || surname.isEmpty) { throw Exception("اسم الطفل واللقب حقول مطلوبة"); }
      if (doctorIdString.isNotEmpty && doctorId == null) { throw Exception("رقم تعريف الأخصائي يجب أن يكون رقمًا صحيحًا"); }

      final result = await AuthService.updateUserProfile(
        token,
        name: name,
        surname: surname,
        doctorId: doctorId,
        imageUrl: _newlyUploadedImageUrl,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // ٥. تخزين الاسم الجديد وتحديث القائمة بعد الحفظ
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('child_name', name);
        // لا نحتاج لتحديث الصورة هنا مرة أخرى لأنها تحدث فور الرفع
        sideBarKey.currentState?.loadDataForDrawer(); // <-- تحديث القائمة بالاسم الجديد

        setState(() { _isSaving = false; _newlyUploadedImageUrl = null; });
        _showSnackBar("تم حفظ التغييرات بنجاح", isError: false);
        
      } else {
        throw Exception(result['message'] ?? 'فشل حفظ التغييرات');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = "فشل حفظ التغييرات: ${e.toString()}"; _isSaving = false; });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green, behavior: SnackBarBehavior.floating, ), );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Directionality(
      textDirection: TextDirection.rtl, 
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70.0),
          child: Padding(
            padding: const EdgeInsets.only(top: 25, right: 10, left: 10),
            child: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_right_outlined, size: 40, color: Color(0xFF2C73D9)),
                onPressed: _isLoading || _isSaving ? null : () => Navigator.maybePop(context),
              ),
              leadingWidth: 40,
              title: const Text( "تعديل الملف الشخصي", style: TextStyle( color: Color(0xFF2C73D9), fontSize: 22, fontWeight: FontWeight.bold, ), ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
        ),
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.01),
                      _buildProfilePictureWidget(context),
                      SizedBox(height: screenHeight * 0.04),
                      if (_errorMessage != null)
                        Padding(
                           padding: const EdgeInsets.only(bottom: 15.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration( color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withAlpha(128)) ),
                            child: Text( _errorMessage!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500, fontSize: 14), textAlign: TextAlign.center, ),
                          ),
                         ),
                      CustomProfileTextField( label: "اسم الطفل", hint: "أدخل اسم طفلك", controller: _nameController, readOnly: _isSaving,),
                      CustomProfileTextField( label: "اللقب", hint: "أدخل اللقب", controller: _surnameController, readOnly: _isSaving, ),
                      CustomProfileTextField( label: "رقم تعريف الأخصائي (اختياري)", hint: "ادخل رقم تعريف الأخصائي إن وجد", controller: _doctorIdController, keyboardType: TextInputType.number, readOnly: _isSaving, ),
                      CustomProfileTextField( label: "تاريخ ميلاد الطفل", hint: "", controller: _childDobController, readOnly: true, suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey), ),
                      CustomProfileTextField( label: "اسم المستخدم (الإيميل)", hint: "", controller: _usernameController, readOnly: true, textDirection: TextDirection.ltr, textAlign: TextAlign.left, suffixIcon: const Icon(Icons.person_outline, color: Colors.grey), ), 
                      CustomProfileTextField( label: "رقم الهاتف", hint: "", controller: _phoneEmailController, readOnly: true, suffixIcon: const Icon(Icons.phone_outlined, color: Colors.grey), ),
                      CustomProfileTextField( label: "كلمة السر", hint: "************", controller: _passwordController, obscureText: true, readOnly: true, suffixIcon: const Icon(Icons.lock_outline, color: Colors.grey), ),
                       Padding(
                         padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                         child: Align( alignment: AlignmentDirectional.centerStart, child: InkWell( onTap: _isLoading || _isSaving ? null : () { Navigator.push( context, MaterialPageRoute(builder: (context) => const ForgetPassword()), ); }, child: const Text( "تغيير كلمة المرور؟", style: TextStyle( fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold,), ), ), ),
                       ),
                      SizedBox(height: screenHeight * 0.03),
                      _buildSaveButtonWidget(context),
                      SizedBox(height: screenHeight * 0.04),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

   Widget _buildProfilePictureWidget(BuildContext context) {
     final screenWidth = MediaQuery.of(context).size.width;
    ImageProvider displayImage;
    if (_selectedImageFile != null && !_isSaving) { displayImage = FileImage(_selectedImageFile!); } else if (_profileImageUrl.startsWith('http')) { displayImage = NetworkImage(_profileImageUrl); } else { displayImage = const AssetImage('assets/images/default_avatar.png'); }
    return Center( child: Stack( clipBehavior: Clip.none, alignment: AlignmentDirectional.bottomEnd, children: [ CircleAvatar( radius: screenWidth * 0.18, backgroundColor: Colors.grey.shade200, backgroundImage: displayImage, onBackgroundImageError: (exception, stackTrace) { print("[EditAccountScreen] Error loading background image: $exception"); }, child: _isSaving && _selectedImageFile != null ? Container( decoration: const BoxDecoration( color: Colors.black45, shape: BoxShape.circle, ), child: const Center( child: CircularProgressIndicator(color: Colors.white), ), ) : null, ), Positioned( right: 0, bottom: 0, child: Material( color: const Color(0xFF2C73D9), shape: const CircleBorder( side: BorderSide(color: Colors.white, width: 2), ), clipBehavior: Clip.antiAlias, elevation: 2, child: InkWell( splashColor: Colors.white.withOpacity(0.3), onTap: _isSaving ? null : _pickAndUploadImage, child: Container( padding: const EdgeInsets.all(6), child: Icon( Icons.camera_alt, size: screenWidth * 0.055, color: Colors.white, ), ), ), ), ), ], ), );
   }

   Widget _buildSaveButtonWidget(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; const double buttonWidthFactor = 0.85; const double buttonHeight = 55; return Center( child: SizedBox( width: screenWidth * buttonWidthFactor, child: ElevatedButton( onPressed: _isLoading || _isSaving ? null : _saveProfileChanges, style: ElevatedButton.styleFrom( backgroundColor: const Color(0xFF2C73D9), foregroundColor: Colors.white, minimumSize: Size(screenWidth * buttonWidthFactor, buttonHeight), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12.0), ), elevation: 3, padding: const EdgeInsets.symmetric(vertical: 12), disabledBackgroundColor: Colors.grey.shade400, disabledForegroundColor: Colors.grey.shade700, ), child: _isSaving ? const SizedBox( width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3), ) : const Text( "حفظ التغييرات", style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, ), ), ), ), );
   }
}