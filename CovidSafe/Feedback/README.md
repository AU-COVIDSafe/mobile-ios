# Feedback

Provides a way for users or testers to send feedback into your JIRA instance from within the app along with a screenshot.

## Configuration

#### JIRA

JIRA Mobile Connect needs to be enabled on a per project basis, otherwise it will not work with your app. Remember, if you are hosting your own JIRA instance, you will need to install the JIRA Mobile Connect plugin on your server before you can enable it.

To enable JIRA Mobile Connect for a project:

1.  Navigate to the desired project > **Project Settings**.
2.  Find the **Settings** section on the page and click **Enable** for the **JIRA Mobile Connect** setting.  
    This will enable the JIRA Mobile Connect plugin for the project, as well as create a user ('jiraconnectuser') in JIRA that is used to create all feedback and crash reports.
3.  To enable the user to create tickets, you must grant it permission to create issues in the project. To do this, grant the 'Create Issues' permission to the 'jiraconnectuser' user. You can do this by adding the user to a group or project role that has the 'Create Issues' permission or grant the permission to the user directly (see [Managing project permissions](https://confluence.atlassian.com/display/AdminJIRACloud/Managing+project+permissions) for help).

#### iOS

Before you can use JIRA Mobile Connect with iOS, you need to identify the JIRA instance that feedback will be sent to. This is done via a JSON file named **JMCTarget**. You'll need to create this **JMCTarget.json** file in your Xcode project and include it in the iOS app's target so it gets bundled with the app.

1.  Right-click your project in Xcode and click **New File...**
2.  Select **Other** in the **iOS** section and click **Next**.
3.  In the **Save As** field, type 'JMCTarget.JSON' then select the desired **Targets**.
4.  Click **Create**.
5.  Add the following code to your new** JMCTarget.JSON** file. Make sure to replace the values with your own:
```
{
  "host": "example-dev.atlassian.net",
  "projectKey": "EXAMPLEKEY",
  "apiKey": "myApiKey"
}
```

_**Note:** Do not prefix the host with `https://`._

## Using JIRA Mobile Connect in your app

### Trigger from the shake-motion event

The shake-motion event is one of the [motion events](https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS/motion_event_basics/motion_event_basics.html#//apple_ref/doc/uid/TP40009541-CH6-SW14) that are detected by the device when it is moved. The following instructions will show you how to trigger a feedback flow (i.e. create a JIRA issue) in your app when the user shakes the device.

_Note that as of iOS 10, `motionEnded` is no longer called on the `AppDelegate`, so you must override `motionEnded` on a `UIResponder` (subclass `UIWindow` or use a top-level view controller)._

Wherever you choose to override `motionEnded`, add the following:

```swift
override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
    do {
        let settings = try FeedbackSettings()
        <WINDOW>.presentFeedbackIfShakeMotion(motion, promptUser: false, settings: settings)
    } catch {
        preconditionFailure("Error retrieving feedback settings: \(error.localizedDescription)")
    }
}
```

### Programmatic trigger

You can also trigger a feedback flow in your app from other events, for example, a button that is tapped in the app. This section shows you how to implement this.
    
Call `presentFeedback()` on any view controller to present feedback:

```swift
do {
    let feedbackSettings = try FeedbackSettings()
    currentViewController.presentFeedback(true, settings: feedbackSettings)
} catch {
    preconditionFailure("Error retrieving feedback settings: \(error.localizedDescription)")
}
```

### Additional Configuration

##### Action sheet prompt

To present an action sheet prompt before taking the user to the feedback flow, set **`promptUser`** to true.

```swift
// Shake Motion
<WINDOW>.presentFeedbackIfShakeMotion(motion, promptUser: true, settings: settings)

// Programmatic
currentViewController.presentFeedback(true, settings: feedbackSettings)
```

##### Reporter details

To pass a string to identify who is sending the feedback, set **`reporterUsernameOrEmail`** to the reporter's Id string.
_**Important**: The current version does not let the user know their ID is being sent. You may want to only use this feature for non-Appstore builds. To do this, just set reporterUsernameOrEmail to `nil` for release builds._

```swift
let settings = try FeedbackSettings(reporterUsernameOrEmail: "someone@example.com")
```
