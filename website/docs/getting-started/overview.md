# Getting Started

**File**: `docs/overview-getting-started.md`
**Purpose**: Quick start guide for first-time users to get Urbalurba running immediately
**Target Audience**: New users and developers trying Urbalurba for the first time
**Last Updated**: September 22, 2024

## 🚀 First Test - 5 Minutes to Running

Get Urbalurba Infrastructure running on your computer in just 5 minutes:

### Step 1: Install Rancher Desktop (2 minutes)

1. **Download Rancher Desktop**: Go to https://rancherdesktop.io/
2. **Install**: Run the installer for your operating system
3. **Start Rancher Desktop**: Launch the application
4. **Wait for Kubernetes**: The Kubernetes cluster will start automatically

### Step 2: Download and Start Urbalurba (3 minutes)

1. **Download**: Go to https://github.com/terchris/urbalurba-infrastructure/releases
2. **Download the latest**: Click on `urbalurba-infrastructure.zip`
3. **Extract**: Unzip the file to your desired folder
4. **Start**: Double-click `start-urbalurba.sh` (macOS/Linux) or `start-urbalurba.bat` (Windows)

### Step 3: Open Your Browser

Once the startup completes (you'll see "All services ready!"), open your browser to:

**http://localhost**

You'll see the Urbalurba welcome page "Hello world"

## 🌐 Starting services

By default you get a catch-all web page that says "Hello world". 


There are two ways of doing this. Starting manually or defining what service should start when the cluster is built.


We will do the simplest way first. Starting sevices manually.

All management is done in the provision-host container. Log in with `./uis shell`.

This takes you into the provision-host and ou should see a prompt like this:
```plaintext
[INFO] Logging into provision-host container...
[INFO] Type 'exit' to return to your local machine

ansible@lima-rancher-desktop:/mnt/urbalurbadisk$
```

### Deploy Your First Service

Let's deploy a simple test service you can see in your browser:

```bash
# Run the simple setup script
./provision-host/kubernetes/99-test/not-in-use/01-setup-whoami-public.sh
```

The script will:
- Test your Kubernetes connection
- Deploy the whoami service and ingress
- Wait for the pod to be ready
- Test that the service responds

The output will be:

```plaintext
.. many lines ...

PLAY RECAP *************************************************************************************************************************************
localhost                  : ok=17   changed=1    unreachable=0    failed=0    skipped=5    rescued=0    ignored=0   

✅ whoami deployment complete
🎉 Open your browser to: http://whoami.localhost
```

When it completes successfully, open your browser to:
**http://whoami.localhost**

You'll see a page showing your request details - this proves your Kubernetes cluster and ingress are working perfectly!

### Monitor Your Cluster with k9s

k9s is a terminal-based Kubernetes dashboard that's already installed in the provision-host:

```bash
# Start k9s to see your cluster
k9s
```

**k9s Navigation Tips**:
- **0** - Show all namespaces
- **:pods** - List all pods
- **:svc** - List all services
- **:deploy** - List all deployments
- **Enter** - View details of selected item
- **l** - View logs of selected pod
- **q** - Quit/go back

**What You'll See**:

A line like this:
```plaintext
default      whoami-76575d99b4-t6q42      1/1   Running
```

- And several system pods keeping Kubernetes running




## 🔧 What's Happening Behind the Scenes

```
┌─────────────────────────────────────────────┐
│           Your Computer                     │
│                                             │
│  ┌──────────────────┐  ┌─────────────────┐  │
│  │ Provision Host   │  │ Kubernetes      │  │
│  │ Container        │─►│ Cluster         │  │
│  │                  │  │                 │  │
│  │ • Installing...  │  │ • Starting...   │  │
│  │ • Configuring... │  │ • Services...   │  │
│  │ • Deploying...   │  │ • Ready!        │  │
│  └──────────────────┘  └─────────────────┘  │
│                            ▲                │
│  ┌─────────────────────────┴──────────────┐ │
│  │        Web Browser                     │ │
│  │  http://whoami.localhost               │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```



1. **Provision Host** downloads and configures all tools
2. **Kubernetes** starts your local services
3. **Browser** connects to the whoami-public and displays its parameters


### How to remove the whoami test

```bash
# Run the simple setup script
./provision-host/kubernetes/99-test/not-in-use/01-remove-whoami-public.sh
```

The service will be removed and you can verify it by using the `k9s`


## 🎯 Next Steps

Once you have the basic system running:

**Explore Services**: Read the [services overview](./services.md) to understand what's available


---

**💡 Goal**: Get you from zero to a running local datacenter in 5 minutes with just a browser and two downloads!