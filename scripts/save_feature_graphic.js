const puppeteer = require('puppeteer');
const path = require('path');

async function generateFeatureGraphic() {
    console.log('フィーチャーグラフィックを生成中...');
    
    // ブラウザを起動
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
        // 新しいページを作成
        const page = await browser.newPage();
        
        // HTMLファイルのパス
        const htmlPath = path.join(__dirname, 'create_feature_graphic.html');
        const fileUrl = `file://${htmlPath}`;
        
        // ページを読み込み
        await page.goto(fileUrl, { waitUntil: 'networkidle0' });
        
        // ビューポートを設定（1024x500ピクセル）
        await page.setViewport({
            width: 1024,
            height: 500,
            deviceScaleFactor: 2 // 高解像度のため2倍
        });
        
        // アニメーションが完了するまで少し待機
        await page.waitForTimeout(3000);
        
        // PNGとして保存
        const outputPath = path.join(__dirname, 'startend_feature_graphic.png');
        await page.screenshot({
            path: outputPath,
            type: 'png',
            fullPage: false,
            omitBackground: false
        });
        
        console.log(`✅ フィーチャーグラフィックが生成されました: ${outputPath}`);
        console.log('📱 Google Playにアップロードしてください');
        
    } catch (error) {
        console.error('❌ エラーが発生しました:', error);
    } finally {
        await browser.close();
    }
}

// スクリプトが直接実行された場合のみ実行
if (require.main === module) {
    generateFeatureGraphic();
}

module.exports = { generateFeatureGraphic }; 