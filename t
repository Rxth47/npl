import os
import requests
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import threading # Import the threading module

# load_dotenv() # Commenting out since the token is provided directly
BOT_TOKEN = "8336243893:AAFoWO5_4dlbxT37Vj3ROpUkXEeE7vBwwmA" # Added the bot token directly

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("👋 Send me a Terabox share link (with optional password).")

def extract_file_info(url, pwd=None):
    headers = {'User-Agent': 'Mozilla/5.0'}
    session = requests.Session()

    if pwd:
        response = session.post(url, data={"pwd": pwd}, headers=headers)
    else:
        response = session.get(url, headers=headers)

    soup = BeautifulSoup(response.text, 'html.parser')

    script_text = ""
    for script in soup.find_all("script"):
        if 'window.__PRELOADED_STATE__' in script.text:
            script_text = script.text
            break

    if not script_text:
        return None

    try:
        import re, json
        json_data = re.search(r'window\.__PRELOADED_STATE__ = (.*?});', script_text).group(1)
        data = json.loads(json_data)
        file_info = data['shareInfo']['file_list'][0]

        filename = file_info.get("filename", "Unknown")
        size = file_info.get("size", 0)
        size_mb = round(size / (1024 * 1024), 2)

        dlink = file_info.get("dlink", "")
        if not dlink.startswith("http"):
            dlink = f"https://d.terabox.com{dlink}"

        return {
            "filename": filename,
            "size": size_mb,
            "link": dlink,
        }
    except:
        return None

async def handle_link(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = update.message.text.strip()
    pwd = None

    if " " in msg:
        msg, pwd = msg.split(" ", 1)
        pwd = pwd.strip()

    await update.message.reply_text("⏳ Extracting file info...")

    info = extract_file_info(msg, pwd)

    if not info:
        await update.message.reply_text("❌ Could not extract file. Make sure the link and password are correct.")
        return

    filename = info['filename']
    size = info['size']
    dlink = info['link']

    keyboard = InlineKeyboardMarkup([
        [InlineKeyboardButton("⬇ Download", url=dlink)],
        [InlineKeyboardButton("👁 View", url=dlink)],
        [InlineKeyboardButton("🔗 Copy Link", url=dlink)],
    ])

    reply_text = f"✅ **File Found**: `{filename}`\n📦 **Size**: {size} MB"
    await update.message.reply_markdown(reply_text, reply_markup=keyboard)

def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_link))
    print("🤖 Bot is running...")
    app.run_polling()

if __name__ == "__main__":
    # Run the bot in a separate thread
    bot_thread = threading.Thread(target=main)
    bot_thread.start()
