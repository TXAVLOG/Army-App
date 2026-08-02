import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ""
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ""

serve(async (req) => {
  try {
    const body = await req.json()
    
    // Google Pub/Sub bọc payload trong message.data ở dạng Base64
    if (!body.message || !body.message.data) {
      return new Response("Missing Pub/Sub message body", { status: 400 })
    }

    const base64Data = body.message.data
    const decodedString = atob(base64Data)
    const notification = JSON.parse(decodedString)

    console.log("Decoded Google Play Notification:", notification)

    const packageName = notification.packageName
    const subscriptionNotification = notification.subscriptionNotification

    if (subscriptionNotification) {
      const subscriptionId = subscriptionNotification.subscriptionId // army_vip_monthly, ...
      const purchaseToken = subscriptionNotification.purchaseToken
      const notificationType = subscriptionNotification.notificationType 
      // notificationType: 
      // 1: RECOVERED, 2: RENEWED, 3: CANCELED, 4: PURCHASED, 12: EXPIRED, 13: PENDING_EXPIRATION...

      const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

      // Cấu hình trạng thái VIP dựa theo loại thông báo
      let isVipActive = true
      let extensionDays = 0

      // Nếu loại thông báo là Hủy gia hạn, Hết hạn, hoặc Tạm ngưng
      if (notificationType === 3 || notificationType === 12 || notificationType === 13 || notificationType === 10) {
        isVipActive = false
      } else if (subscriptionId.includes('yearly')) {
        extensionDays = 365
      } else {
        extensionDays = 30 // Gói tháng mặc định
      }

      const expiryDate = new Date()
      expiryDate.setDate(expiryDate.getDate() + extensionDays)

      // Cập nhật thông tin VIP vào bảng txa_users
      const { data, error } = await supabase
        .from('txa_users')
        .update({
          isVipActive: isVipActive,
          vipExpiryDate: isVipActive ? expiryDate.toISOString() : new Date().toISOString(),
          vipProductId: subscriptionId,
        })
        .eq('vipPurchaseToken', purchaseToken)

      if (error) {
        console.error(`Error updating database for token ${purchaseToken}:`, error)
        throw error
      }
      
      console.log(`Processed notification for token: ${purchaseToken}. isVipActive: ${isVipActive}`)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    console.error("Webhook processing error:", err.message)
    return new Response(err.message, { status: 500 })
  }
})
