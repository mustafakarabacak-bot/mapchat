#!/bin/bash

# Firebase Rules Deploy Script
# HERŞEYİ SERBEST MODU - GELİŞTİRME İÇİN

echo "🔥 Firebase Rules Deploy - SERBEST MOD"
echo "⚠️  SADECE GELİŞTİRME İÇİN!"

# Firestore Rules Deploy
echo "📊 Firestore rules deploy ediliyor..."
firebase deploy --only firestore:rules

# Storage Rules Deploy  
echo "📁 Storage rules deploy ediliyor..."
firebase deploy --only storage

echo "✅ Tüm kurallar deploy edildi!"
echo "🎯 Artık tüm işlemler serbest!"

# Test connection
echo "🧪 Firebase bağlantısını test et..."
curl -X GET "https://mapchat-23288-default-rtdb.firebaseio.com/.json" || echo "Test başarısız"

echo "🚀 READY TO GO! 🚀"
