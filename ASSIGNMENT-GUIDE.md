# Assignment Guide: Dynamic Web Application with MongoDB

This guide explains how to interact with your web application, edit the name in MongoDB, and verify all assignment requirements.

---

## Architecture Overview

Your application consists of three main components:

1. **Frontend** (Lighttpd + HTML/JavaScript)
   - Serves static HTML page
   - Fetches data from API using JavaScript
   - Displays name dynamically

2. **API** (FastAPI/Python)
   - `/api/name` - Returns name from database
   - `/api/container-id` - Returns container/pod ID
   - `/health` - Health check endpoint

3. **Database** (MongoDB)
   - Stores your name in `fkdb` database
   - Collection: `profile`
   - Document structure: `{ "key": "name", "value": "Your Name" }`
   - **Persistent storage**: Uses PersistentVolume - data persists across pod restarts

---

## Accessing the Application

### Method 1: Via Domain Name (Recommended)
```
https://fk-webserver.duckdns.org:30808/
```

### Method 2: Via IP Address
```
https://192.168.56.12:30808/
```

### Method 3: Via localhost (Port Forward)
```powershell
# From PowerShell on Windows
vagrant ssh fk-control -c "kubectl port-forward -n fk-webstack svc/fk-frontend 8080:80"

# Then access in browser:
http://localhost:8080/
```

---

## API Endpoints Reference

### 1. Get Name from Database
**Endpoint:** `/api/name`  
**Method:** GET  
**Description:** Retrieves the current name stored in MongoDB

**Access via curl:**
```bash
# Via domain
curl https://fk-webserver.duckdns.org:30808/api/name

# Via IP
curl https://192.168.56.12:30808/api/name

# From inside cluster
kubectl exec -it <pod-name> -n fk-webstack -- curl http://fk-api:8000/api/name
```

**Response:**
```json
{
  "name": "Frank Koch"
}
```

---

### 2. Get Container/Pod ID
**Endpoint:** `/api/container-id`  
**Method:** GET  
**Description:** Returns the hostname/container ID of the API pod (useful to see which pod is serving requests)

**Access via curl:**
```bash
# Via domain
curl https://fk-webserver.duckdns.org:30808/api/container-id

# Via IP
curl https://192.168.56.12:30808/api/container-id
```

**Response:**
```json
{
  "container_id": "fk-api-ffc844dbb-bfjnm"
}
```

---

### 3. Health Check
**Endpoint:** `/health`  
**Method:** GET  
**Description:** Returns health status of the API (used by Kubernetes for liveness/readiness probes)

**Access via curl:**
```bash
curl https://fk-webserver.duckdns.org:30808/health
```

**Response:**
```json
{
  "status": "ok"
}
```

---

## How to Edit the Name in MongoDB

**⚠️ IMPORTANT for Windows PowerShell Users:**  
PowerShell has issues with special characters (`$`) in one-liner commands. You MUST use the two-step method below (SSH into the VM first, then run the command). This is the ONLY method that works reliably.

**Note:** MongoDB now uses persistent storage, so your changes will survive pod restarts, VM reboots, and cluster maintenance.

### Two-Step Method (ONLY Method That Works)

**This is the ONLY tested and working method:**

```powershell
# Step 1: SSH into the VM
vagrant ssh fk-control

# Step 2: Inside the VM, run the update command
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.updateOne({key:"name"},{$set:{value:"Jeroen Verbruggen"}})'

# Step 3: Exit the VM
exit
```

**Why two steps?** PowerShell treats `$` as a variable prefix, causing escaping issues with one-liners. Once inside the VM, you're in Linux and these issues disappear.

**Concrete Example - Change "Frank Koch" to "Jeroen Verbruggen":**
```powershell
# From PowerShell on Windows:
vagrant ssh fk-control
# Now you're inside the VM, run:
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.updateOne({key:"name"},{$set:{value:"Jeroen Verbruggen"}})'
```

**Expected Output:**
```json
{
  acknowledged: true,
  insertedId: null,
  matchedCount: 1,
  modifiedCount: 1,
  upsertedCount: 0
}
```

**Verify the change:**
```bash
curl https://fk-webserver.duckdns.org:30808/api/name
```

**Should return:**
```json
{
  "name": "Jeroen Verbruggen"
}
```

**To view current data (also works as two-step):**
```powershell
# Step 1: SSH into VM
vagrant ssh fk-control

# Step 2: View data
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.find().pretty()'
```

---

### Adding Additional Entries (Instead of Replacing)

If you want to add more entries to the database instead of changing the existing name:

**Add a new entry:**
```powershell
# Step 1: SSH into VM
vagrant ssh fk-control

# Step 2: Insert a new document
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.insertOne({key:"student",value:"John Doe"})'
```

**Expected Output:**
```json
{
  acknowledged: true,
  insertedId: ObjectId('...')
}
```

**View all entries:**
```powershell
# Still inside the VM after ssh
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.find().pretty()'
```

**You'll see:**
```javascript
{
  _id: ObjectId('...'),
  key: 'name',
  value: 'Frank Koch'
}
{
  _id: ObjectId('...'),
  key: 'student',
  value: 'John Doe'
}
```

**Delete a specific entry:**
```powershell
# Still inside the VM
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.deleteOne({key:"student"})'
```

**Expected Output:**
```json
{
  acknowledged: true,
  deletedCount: 1
}
```

---

## Verifying the Assignment Requirements

### Requirement 1: Web Frontend Shows JavaScript Page

**Test:**
1. Open browser: https://fk-webserver.duckdns.org:30808/
2. You should see: "**[Your Name] has reached milestone 2!**"

**Verify JavaScript is working:**
- Right-click → Inspect → Console
- You should see the API request to `/api/name`
- No errors in console

---

### Requirement 2: Page Layout Changes Automatically

**Current Behavior:**
- The frontend HTML is static
- JavaScript dynamically loads the name from API
- When API returns different data, the page displays it

**To demonstrate dynamic updates:**
1. Open the webpage
2. Note the current name displayed
3. Change the name in MongoDB (see methods above)
4. **Refresh the browser page (F5)**
5. The new name should appear automatically

---

### Requirement 3: API Endpoint Returns Name from Database

**Test:**
```bash
# Test the /api/name endpoint
curl https://fk-webserver.duckdns.org:30808/api/name
```

**Expected Response:**
```json
{
  "name": "Frank Koch"
}
```

**Verify it reads from database:**
1. Change name in MongoDB
2. Call API endpoint again
3. New name should be returned

---

### Requirement 4: API Endpoint Returns Container ID

**Test:**
```bash
# Test the /api/container-id endpoint
curl https://fk-webserver.duckdns.org:30808/api/container-id
```

**Expected Response:**
```json
{
  "container_id": "fk-api-ffc844dbb-bfjnm"
}
```

**This shows:**
- The pod hostname (container ID)
- Which API pod served your request
- Useful when you have multiple API replicas (horizontal scaling)

---

### Requirement 5: Name Changes Reflect on Webpage After Refresh

**Step-by-Step Test:**

1. **View current name on webpage:**
   - Open: https://fk-webserver.duckdns.org:30808/
   - Note the name displayed

2. **Change name in database:**
   ```powershell
   # Step 1: SSH into the VM
   vagrant ssh fk-control
   
   # Step 2: Inside the VM, run:
   kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.updateOne({key:"name"},{$set:{value:"Jeroen Verbruggen"}})'
   
   # Step 3: Exit the VM
   exit
   ```

3. **Verify API returns new name:**
   ```bash
   curl https://fk-webserver.duckdns.org:30808/api/name
   # Should return: {"name": "Jeroen Verbruggen"}
   ```

4. **Refresh the webpage:**
   - Press F5 or Ctrl+R
   - The new name should appear immediately

---

### Requirement 6: Database Stores the Name

**Verify database content:**
```bash
# Step 1: SSH into VM
vagrant ssh fk-control

# Step 2: Check database content
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.find().pretty()'
```

**Expected Output:**
```javascript
{
  _id: ObjectId('...'),
  key: 'name',
  value: 'Frank Koch'  // or 'Jeroen Verbruggen' if you changed it
}
```

**Bonus - Test Persistence Across Pod Restarts:**
```bash
# Delete the MongoDB pod
vagrant ssh fk-control -c "kubectl delete pod -n fk-webstack -l app=fk-mongodb"

# Wait for pod to restart (15-20 seconds)
sleep 20

# Verify data is still there
curl https://fk-webserver.duckdns.org:30808/api/name
# Should still return your name!
```

---

## Complete Demo Workflow

Here's a complete workflow to demonstrate all requirements:

### From Windows PowerShell:

```powershell
# 1. Check deployment status
vagrant ssh fk-control -c "kubectl get all -n fk-webstack"

# 2. Test API endpoint - Get name
curl https://fk-webserver.duckdns.org:30808/api/name

# 3. Test API endpoint - Get container ID
curl https://fk-webserver.duckdns.org:30808/api/container-id

# 4. Open webpage in browser
start https://fk-webserver.duckdns.org:30808/

# 5. Change the name in database (Example: Frank Koch → Jeroen Verbruggen)
# IMPORTANT: This is a two-step process - SSH first, then run command inside VM
vagrant ssh fk-control

# 6. Now inside the VM, run these commands:
# View current data
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.find().pretty()'

# Update the name
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.updateOne({key:"name"},{$set:{value:"Jeroen Verbruggen"}})'

# Exit the VM
exit

# 7. Verify API returns new name (back in PowerShell)
curl https://fk-webserver.duckdns.org:30808/api/name
# Should return: {"name": "Jeroen Verbruggen"}

# 8. Refresh browser - name should update!
```

---

## Advanced: Creating a Full CRUD Interface (Optional)

If you want to make the frontend editable without MongoDB access:

### Add Update Endpoint to API

Edit `api/app/main.py` and add:

```python
from fastapi import HTTPException
from pydantic import BaseModel

class NameUpdate(BaseModel):
    name: str

@app.put("/api/name")
def update_name(update: NameUpdate):
    """Update name in database"""
    try:
        coll = get_db_collection()
        if coll is None:
            raise HTTPException(status_code=503, detail="Database unavailable")
        
        result = coll.update_one(
            {"key": NAME_KEY},
            {"$set": {"value": update.name}},
            upsert=True
        )
        
        return {"success": True, "name": update.name}
    except Exception as e:
        logger.error(f"Error updating name: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

### Update Frontend with Edit Form

Edit `frontend/index.html` to add:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Milestone 2</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        max-width: 800px;
        margin: 50px auto;
        padding: 20px;
      }
      input[type="text"] {
        padding: 10px;
        width: 300px;
        font-size: 16px;
      }
      button {
        padding: 10px 20px;
        font-size: 16px;
        cursor: pointer;
      }
    </style>
  </head>
  <body>
    <h1><span id="user">Loading...</span> has reached milestone 2!</h1>
    
    <div>
      <h2>Edit Name:</h2>
      <input type="text" id="nameInput" placeholder="Enter new name" />
      <button onclick="updateName()">Update Name</button>
      <p id="status"></p>
    </div>

    <script>
      const apiUrl = window.location.hostname === "localhost" 
        ? "http://localhost:8000"
        : "";
      
      function loadName() {
        fetch(apiUrl + "/api/name")
          .then((res) => res.json())
          .then((data) => {
            document.getElementById("user").innerText = data.name;
            document.getElementById("nameInput").value = data.name;
          });
      }
      
      function updateName() {
        const newName = document.getElementById("nameInput").value;
        
        fetch(apiUrl + "/api/name", {
          method: "PUT",
          headers: {
            "Content-Type": "application/json"
          },
          body: JSON.stringify({ name: newName })
        })
        .then(res => res.json())
        .then(data => {
          document.getElementById("status").innerText = "Name updated successfully!";
          loadName();
          setTimeout(() => {
            document.getElementById("status").innerText = "";
          }, 3000);
        })
        .catch(err => {
          document.getElementById("status").innerText = "Error updating name!";
        });
      }
      
      // Load name on page load
      loadName();
    </script>
  </body>
</html>
```

Then rebuild and redeploy:
```bash
vagrant ssh fk-control
cd /vagrant
kubectl delete -f k8s/30-frontend-deployment.yaml
kubectl apply -f k8s/30-frontend-deployment.yaml
```

---

## Troubleshooting

### Name doesn't update on webpage

**Check 1: API is returning correct data**
```bash
curl https://fk-webserver.duckdns.org:30808/api/name
```

**Check 2: Database has correct value**
```bash
# SSH into VM first
vagrant ssh fk-control

# Then check database
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.find()'
```

**Check 3: Browser cache**
- Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
- Or open in Incognito/Private mode

**Check 4: Check API logs**
```bash
vagrant ssh fk-control -c "kubectl logs -f -n fk-webstack -l app=fk-api"
```

---

### Cannot connect to MongoDB

**Check MongoDB pod is running:**
```bash
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack -l app=fk-mongodb"
```

**Check MongoDB logs:**
```bash
vagrant ssh fk-control -c "kubectl logs -n fk-webstack -l app=fk-mongodb"
```

**Restart MongoDB pod:**
```bash
vagrant ssh fk-control -c "kubectl delete pod -n fk-webstack -l app=fk-mongodb"
```

---

## Quick Reference Commands

**⚠️ PowerShell Users:** Always use the two-step method (SSH into VM first, then run command).

```powershell
# View current name via API
curl https://fk-webserver.duckdns.org:30808/api/name

# View container ID
curl https://fk-webserver.duckdns.org:30808/api/container-id

# Update name in MongoDB - TWO-STEP METHOD (ONLY method that works)
# Step 1: SSH into VM
vagrant ssh fk-control
# Step 2: Run this inside the VM:
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.updateOne({key:"name"},{$set:{value:"New Name"}})'

# Example: Change to "Jeroen Verbruggen" (run AFTER 'vagrant ssh fk-control')
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.updateOne({key:"name"},{$set:{value:"Jeroen Verbruggen"}})'

# View MongoDB content (run AFTER 'vagrant ssh fk-control')
kubectl exec $(kubectl get pod -n fk-webstack -l app=fk-mongodb -o jsonpath='{.items[0].metadata.name}') -n fk-webstack -- mongosh fkdb --eval 'db.profile.find().pretty()'

# Check all pods status
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack"

# View API logs
vagrant ssh fk-control -c "kubectl logs -f -n fk-webstack -l app=fk-api"

# Restart API pods
vagrant ssh fk-control -c "kubectl rollout restart deployment/fk-api -n fk-webstack"
```

---

## Assignment Checklist

- [x] Web frontend shows JavaScript page
- [x] Frontend fetches and displays name from API
- [x] API endpoint `/api/name` returns name from database
- [x] API endpoint `/api/container-id` returns container ID
- [x] When name changes in database, webpage shows new name after refresh
- [x] Database (MongoDB) stores the name persistently
- [x] All components running in Kubernetes
- [x] Accessible via HTTPS with proper ingress

---

*Last updated: 2026-02-22*
