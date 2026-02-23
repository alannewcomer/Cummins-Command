# Cummins Command V2 — Multi-Vehicle & Sharing System

## Adding Vehicles

1. Tap "+" in vehicle picker or go to **Settings > Vehicles > Add Vehicle**
2. Enter VIN → Cloud Function calls **NHTSA VIN Decoder API** → auto-populates:
   - Year, make, model, engine, transmission, factory specs
3. Manual override for any field
4. Set as active vehicle immediately or later
5. Each vehicle gets its own: drives, datapoints, dashboards, maintenance, AI context — **completely isolated**

## Vehicle Data Model

```
users/{userId}/vehicles/{vehicleId}
  year, make, model, trim, vin, engine, transmissionType
  currentOdometer, purchaseDate, purchaseMileage
  towingCapacity, payloadCapacity, gvwr
  isActive: boolean (which vehicle is currently selected)
  modHistory: array of mods with dates (intake, exhaust, tuner, etc.)
  baselineSnapshots: AI-generated baseline data at stock and after each mod
```

## Sharing Vehicles

### Invite by Email
- Enter email address
- Choose granular permissions:
  - `viewLive` — See live gauges
  - `viewHistory` — See drive history
  - `viewAI` — See AI analysis and insights
  - `viewMaintenance` — See maintenance log
  - `editMaintenance` — Add/edit maintenance records
  - `manageDashboards` — Create/edit dashboards
- Recipient gets a push notification
- Vehicle appears in their vehicle list

### Invite by Link
- Generate a short share code (e.g., `cummins.cmd/share/a3x9k2`)
- Anyone with the link can request access
- Owner approves with selected permissions

### Manage Shares
- See all users with access to each vehicle
- Modify permissions at any time
- Revoke access at any time

## Sharing Data Model

```
users/{userId}/vehicles/{vehicleId}/sharing/{shareId}
  sharedWithUserId or sharedWithEmail
  permissions: {
    viewLive: boolean,
    viewHistory: boolean,
    viewAI: boolean,
    viewMaintenance: boolean,
    editMaintenance: boolean,
    manageDashboards: boolean
  }
  status: "pending" | "accepted" | "revoked"
  inviteCode: short code for link-based sharing
  createdAt, acceptedAt
```

## Vehicle Switching

- Header on **every screen** shows the active vehicle name
- Tap → vehicle picker bottom sheet
- Switch is **instant** — all providers reload for the new vehicle
- Dashboard, history, AI context, and maintenance all switch
- Each vehicle maintains its own last-viewed state

## Use Cases

- Dad shares his 3500 with you so you can monitor his truck remotely
- Fleet manager shares work trucks with drivers
- Mechanic gets temporary read-only access for diagnostics

## Cloud Function: processVehicleShare

Triggered on `onDocumentCreated` for `sharing/{shareId}`:
- Sends invite notification via FCM
- Sets up cross-user access in Firestore security rules
- Handles both email-based and link-based sharing flows
