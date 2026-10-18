// Inert stand-ins for the Android-only UnityEngine classes. The Android build of the game references
// them (compiled with UNITY_ANDROID); Unity's iOS UnityEngine.dll does not contain them. The game guards
// its Android calls with Application.platform checks, so on iOS these normally never run. If something
// does call them, the calls are no-ops that return default values, as if the Java side were absent.
using System;

namespace UnityEngine
{
    public class AndroidJavaObject : IDisposable
    {
        protected AndroidJavaObject() { }
        public AndroidJavaObject(string className, params object[] args) { }

        public void Call(string methodName, params object[] args) { }
        public T Call<T>(string methodName, params object[] args) { return default(T); }
        public void CallStatic(string methodName, params object[] args) { }
        public T CallStatic<T>(string methodName, params object[] args) { return default(T); }
        public T Get<T>(string fieldName) { return default(T); }
        public void Set<T>(string fieldName, T val) { }
        public T GetStatic<T>(string fieldName) { return default(T); }
        public void SetStatic<T>(string fieldName, T val) { }
        public IntPtr GetRawObject() { return IntPtr.Zero; }
        public IntPtr GetRawClass() { return IntPtr.Zero; }
        public void Dispose() { }
    }

    public class AndroidJavaClass : AndroidJavaObject
    {
        public AndroidJavaClass(string className) { }
    }

    public static class AndroidJNI
    {
        public static IntPtr ExceptionOccurred() { return IntPtr.Zero; }
        public static void ExceptionDescribe() { }
        public static void ExceptionClear() { }
    }
}
