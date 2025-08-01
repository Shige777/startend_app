package com.startend.sns.app

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_layout, null) as NativeAdView

        // ヘッドライン
        nativeAdView.headlineView = nativeAdView.findViewById(R.id.ad_headline)
        val headlineView = nativeAdView.headlineView as TextView
        headlineView.text = nativeAd.headline
        headlineView.maxLines = 1
        headlineView.ellipsize = android.text.TextUtils.TruncateAt.END
        headlineView.setPadding(0, 0, 0, 0)
        headlineView.setBackgroundColor(android.graphics.Color.TRANSPARENT)

        // ボディ
        nativeAdView.bodyView = nativeAdView.findViewById(R.id.ad_body)
        if (nativeAd.body == null || nativeAd.body?.isEmpty() == true) {
            nativeAdView.bodyView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.bodyView?.visibility = View.VISIBLE
            val bodyView = nativeAdView.bodyView as TextView
            bodyView.text = nativeAd.body
            bodyView.maxLines = 1
            bodyView.ellipsize = android.text.TextUtils.TruncateAt.END
            bodyView.setPadding(0, 0, 0, 0)
            bodyView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }

        // コールトゥアクション
        nativeAdView.callToActionView = nativeAdView.findViewById(R.id.ad_call_to_action)
        if (nativeAd.callToAction == null || nativeAd.callToAction?.isEmpty() == true) {
            nativeAdView.callToActionView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.callToActionView?.visibility = View.VISIBLE
            val ctaView = nativeAdView.callToActionView as Button
            ctaView.text = nativeAd.callToAction
            ctaView.setPadding(0, 0, 0, 0)
        }

        // アイコン
        nativeAdView.iconView = nativeAdView.findViewById(R.id.ad_icon)
        if (nativeAd.icon == null) {
            nativeAdView.iconView?.visibility = View.GONE
        } else {
            val iconView = nativeAdView.iconView as ImageView
            iconView.setImageDrawable(nativeAd.icon?.drawable)
            iconView.scaleType = ImageView.ScaleType.FIT_CENTER
            iconView.setPadding(0, 0, 0, 0)
            iconView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
            nativeAdView.iconView?.visibility = View.VISIBLE
        }

        // 星評価
        nativeAdView.starRatingView = nativeAdView.findViewById(R.id.ad_stars)
        if (nativeAd.starRating == null) {
            nativeAdView.starRatingView?.visibility = View.INVISIBLE
        } else {
            val ratingView = nativeAdView.starRatingView as RatingBar
            ratingView.rating = nativeAd.starRating!!.toFloat()
            ratingView.visibility = View.VISIBLE
        }

        // 広告主名 - 必ずネイティブ広告ビュー内に配置
        nativeAdView.advertiserView = nativeAdView.findViewById(R.id.ad_advertiser)
        if (nativeAd.advertiser == null || nativeAd.advertiser?.isEmpty() == true) {
            nativeAdView.advertiserView?.visibility = View.INVISIBLE
        } else {
            val advertiserView = nativeAdView.advertiserView as TextView
            advertiserView.text = nativeAd.advertiser
            advertiserView.maxLines = 1
            advertiserView.ellipsize = android.text.TextUtils.TruncateAt.END
            advertiserView.setPadding(0, 0, 0, 0)
            advertiserView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
            nativeAdView.advertiserView?.visibility = View.VISIBLE
        }

        // ネイティブ広告を設定
        nativeAdView.setNativeAd(nativeAd)

        return nativeAdView
    }
} 