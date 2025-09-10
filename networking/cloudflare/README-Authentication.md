# Cloudflare Tunnel Authentication Guide

## Overview

When setting up a Cloudflare tunnel, you'll need to complete a 2-step browser authentication process to authorize tunnel creation for your domain.

## Prerequisites

1. **Cloudflare Account**: You must have a Cloudflare account with the domain already added
2. **Domain Status**: Your domain must show as "Active" in the Cloudflare dashboard
3. **Browser Access**: You need a browser on the same machine where you're running the scripts

## Authentication Flow

### Step 1: Verify Dashboard Access

Before running the setup script:

1. Login to Cloudflare dashboard: https://dash.cloudflare.com/login
2. Verify your domain appears in the list and shows "Active" status
3. Ensure you're logged into the correct Cloudflare account that owns the domain

### Step 2: Browser Authentication Process

When you run `./820-cloudflare-tunnel-setup.sh [domain]`, the script will:

1. **Show a browser URL** - A link will appear in the terminal
2. **Open the link** - Click or copy the URL to your browser

#### Browser Step 1: Select Domain Zone

- You'll see a page titled "Authorize Cloudflare Tunnel"
- A table shows all domains in your account with columns: Name, Status, Account, Plan, Plan Status
- **ACTION REQUIRED**: Click on the row for your specific domain (e.g., urbalurba.no)
- All domains should show "Active" status with green checkmarks

#### Browser Step 2: Authorize Tunnel Creation

- You'll see a confirmation dialog: "Authorize Tunnel for [your-domain]"
- Message: "To finish configuring Tunnel for your zone, click Authorize below"
- **ACTION REQUIRED**: Click the blue "Authorize" button (NOT "Cancel")

#### Browser Step 3: Success Confirmation

- You'll see a "Success" page
- Message: "Cloudflared has installed a certificate allowing your origin to create a Tunnel on this zone"
- Final message: "You may now close this window and start your Cloudflare Tunnel!"
- **ACTION**: Close the browser window and return to the terminal

## Troubleshooting

### "Unauthorized" Errors

If you see REST API unauthorized errors:

1. **Wrong Account**: Make sure you're logged into the Cloudflare account that owns the domain
2. **Incomplete Auth**: You must complete BOTH steps in the browser (select domain AND authorize)
3. **Domain Not Active**: Verify your domain shows "Active" status in Cloudflare dashboard

### Authentication Timeout

- The browser authentication link has a timeout
- If it expires, run the script again to get a fresh link
- Complete the browser steps quickly after clicking the link

### Multiple Domains

- If you have multiple domains in your account, make sure to select the correct one
- The domain must match exactly what you passed to the script

## Script Integration

The authentication process is integrated into:

- `820-cloudflare-tunnel-setup.sh` - Creates tunnel and handles authentication
- The script will pause and wait for you to complete the browser steps
- Only proceed in the terminal after seeing the "Success" page in browser

## Security Notes

- The certificate downloaded during this process is specific to your domain
- It's stored securely in `/mnt/urbalurbadisk/cloudflare/cloudflare-certificate.pem`
- The tunnel credentials are encrypted and stored in Kubernetes secrets
- Never share the certificate or credential files