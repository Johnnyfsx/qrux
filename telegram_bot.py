import os
import subprocess
from telegram import Update
from telegram.ext import Application, CommandHandler, CallbackContext

# Function to read the bot token and chat ID from the config file
def load_bot_config(config_file_path):
    bot_token = None
    chat_id = None
    try:
        with open(config_file_path, 'r') as file:
            for line in file:
                if "BOT_TOKEN:" in line:
                    bot_token = line.split(":", 1)[1].strip()
                elif "CHAT_ID:" in line:
                    chat_id = line.split(":", 1)[1].strip()
    except Exception as e:
        print(f"Error reading config file: {e}")
    
    return bot_token, chat_id

# Function to execute server-side commands
def run_server_function(command):
    try:
        result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result.stdout.decode('utf-8') if result.returncode == 0 else result.stderr.decode('utf-8')
    except Exception as e:
        return str(e)

# Asynchronous command to start the bot
async def start(update: Update, context: CallbackContext) -> None:
    await update.message.reply_text('Hello! I am your bot. Use /run <command> to execute a server function.')

# Asynchronous command to execute a server function
async def run_command(update: Update, context: CallbackContext) -> None:
    if context.args:
        command = ' '.join(context.args)
        result = run_server_function(command)
        await update.message.reply_text(f'Command executed: {result}')
    else:
        await update.message.reply_text('Please provide a command to run. Example: /run ls -l')

def main() -> None:
    # Path to the configuration file
    config_file_path = '/var/www/html/Qrux_config.txt'
    
    # Load the bot token and chat ID
    TOKEN, CHAT_ID = load_bot_config(config_file_path)

    if not TOKEN or not CHAT_ID:
        print("Error: BOT_TOKEN or CHAT_ID not found in config file.")
        return

    # Initialize the bot application
    application = Application.builder().token(TOKEN).build()

    # Register the command handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("run", run_command))

    # Start the bot
    application.run_polling()

if __name__ == '__main__':
    main()
