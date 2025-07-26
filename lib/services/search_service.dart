import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final lowercaseQuery = query.toLowerCase();
      List<Map<String, dynamic>> results = [];

      // users koleksiyonunda arama yap
      final usersQuery = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('username', isLessThan: lowercaseQuery + '\uf8ff')
          .limit(10)
          .get();

      for (var doc in usersQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        results.add(data);
      }

      // user_contacts koleksiyonunda da arama yap
      final contactsQuery = await _firestore
          .collection('user_contacts')
          .limit(20)
          .get();

      for (var doc in contactsQuery.docs) {
        final data = doc.data();
        final email = data['email']?.toString().toLowerCase() ?? '';
        final firstName = data['firstName']?.toString().toLowerCase() ?? '';
        final lastName = data['lastName']?.toString().toLowerCase() ?? '';
        final fullName = data['fullName']?.toString().toLowerCase() ?? '';
        final phone = data['phone']?.toString() ?? '';
        final username = data['username']?.toString().toLowerCase() ?? '';

        // Arama teriminin herhangi bir alanda olup olmadığını kontrol et
        if (email.contains(lowercaseQuery) ||
            firstName.contains(lowercaseQuery) ||
            lastName.contains(lowercaseQuery) ||
            fullName.contains(lowercaseQuery) ||
            phone.contains(query) ||
            username.contains(lowercaseQuery)) {
          
          // Ana users koleksiyonundan tam veriyi al
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(data['userId'])
                .get();
            
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              userData['id'] = userDoc.id;
              
              // Duplikasyonu önle
              if (!results.any((item) => item['id'] == userDoc.id)) {
                results.add(userData);
              }
            }
          } catch (e) {
            developer.log('Error fetching user data: $e');
          }
        }
      }

      // Sonuçları sınırla
      if (results.length > 10) {
        results = results.take(10).toList();
      }

      developer.log('Search results for "$query": ${results.length} users found');
      return results;
    } catch (e) {
      developer.log('Error searching users: $e');
      return [];
    }
  }
}
