// ILPatch: prepares the Android build's managed assemblies for Unity's iOS IL2CPP player.
//
//   mono ILPatch.exe check <managed dir> <ios UnityEngine.dll>
//       Resolves every type and member the game assemblies use from UnityEngine against the iOS
//       variant and lists what is missing.
//   mono ILPatch.exe patch <in managed dir> <out managed dir> <ios UnityEngine.dll>
//       Copies the assemblies, replaces UnityEngine.dll with the iOS one and applies the stubs in
//       Stubs (the Android-only code paths that were compiled in with UNITY_ANDROID).
//
// Built against the Mono.Cecil that ships with Unity's IL2CPP (0.9.5), see tools/ilpatch/build.sh.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Mono.Cecil;
using Mono.Cecil.Cil;

static class ILPatch
{
    static readonly string[] Framework = {
        "mscorlib.dll", "System.dll", "System.Core.dll", "System.Xml.dll", "Mono.Security.dll", "UnityEngine.dll"
    };

    static int Main(string[] args)
    {
        if (args.Length >= 3 && args[0] == "check") return Check(args[1], args[2]);
        if (args.Length >= 4 && args[0] == "patch") return Patch(args[1], args[2], args[3]);
        Console.Error.WriteLine("usage: ILPatch check <managed> <ios UnityEngine.dll> | patch <in> <out> <ios UnityEngine.dll>");
        return 2;
    }

    static IEnumerable<string> GameAssemblies(string dir)
    {
        return Directory.GetFiles(dir, "*.dll").Where(p => !Framework.Contains(Path.GetFileName(p))).OrderBy(p => p);
    }

    static DefaultAssemblyResolver Resolver(string managed, string unityEngineDir)
    {
        var r = new DefaultAssemblyResolver();
        foreach (var d in r.GetSearchDirectories()) r.RemoveSearchDirectory(d);
        r.AddSearchDirectory(unityEngineDir);
        r.AddSearchDirectory(managed);
        return r;
    }

    // Lists every UnityEngine type/member reference of the game assemblies that the given UnityEngine lacks.
    static int Check(string managed, string iosEngine)
    {
        var engineDir = Path.GetDirectoryName(Path.GetFullPath(iosEngine));
        var resolver = Resolver(managed, engineDir);
        var p = new ReaderParameters { AssemblyResolver = resolver };
        var engine = AssemblyDefinition.ReadAssembly(iosEngine, p).MainModule;
        int missing = 0;
        foreach (var path in GameAssemblies(managed))
        {
            var mod = AssemblyDefinition.ReadAssembly(path, p).MainModule;
            var seen = new HashSet<string>();
            foreach (var tr in mod.GetTypeReferences())
            {
                if (ScopeName(tr) != "UnityEngine") continue;
                if (engine.GetType(tr.FullName) == null && Resolve(tr) == null && seen.Add("T " + tr.FullName))
                {
                    Console.WriteLine("{0}: missing type {1}", mod.Name, tr.FullName);
                    missing++;
                }
            }
            foreach (var mr in mod.GetMemberReferences())
            {
                var decl = mr.DeclaringType;
                while (decl is TypeSpecification) decl = ((TypeSpecification)decl).ElementType;
                if (decl == null || ScopeName(decl) != "UnityEngine") continue;
                object resolved = null;
                try { resolved = mr is MethodReference ? (object)((MethodReference)mr).Resolve() : ((FieldReference)mr).Resolve(); }
                catch (Exception) { }
                if (resolved == null && seen.Add("M " + mr.FullName))
                {
                    Console.WriteLine("{0}: missing member {1}", mod.Name, mr.FullName);
                    missing++;
                }
            }
        }
        Console.WriteLine("{0} missing", missing);
        return missing == 0 ? 0 : 1;
    }

    static TypeDefinition Resolve(TypeReference tr)
    {
        try { return tr.Resolve(); } catch (Exception) { return null; }
    }

    static string ScopeName(TypeReference tr)
    {
        while (tr.DeclaringType != null) tr = tr.DeclaringType;
        var s = tr.Scope;
        if (s is AssemblyNameReference) return ((AssemblyNameReference)s).Name;
        if (s is ModuleDefinition) return ((ModuleDefinition)s).Assembly.Name.Name;
        return s == null ? "" : s.Name;
    }

    static int Patch(string inDir, string outDir, string iosEngine)
    {
        Directory.CreateDirectory(outDir);
        foreach (var f in Directory.GetFiles(inDir, "*.dll"))
            File.Copy(f, Path.Combine(outDir, Path.GetFileName(f)), true);
        File.Copy(iosEngine, Path.Combine(outDir, "UnityEngine.dll"), true);
        var resolver = Resolver(outDir, outDir);
        var p = new ReaderParameters { AssemblyResolver = resolver };
        int changed = 0;
        var shimPath = Path.Combine(outDir, "AndroidShim.dll");
        var shim = AssemblyDefinition.ReadAssembly(shimPath, p);
        foreach (var path in GameAssemblies(outDir).Where(f => f != shimPath).ToList())
        {
            var asm = AssemblyDefinition.ReadAssembly(path, p);
            int n = Stubs.Apply(asm.MainModule) + RetargetToShim(asm.MainModule, shim);
            if (n > 0)
            {
                var tmp = path + ".tmp";
                asm.Write(tmp);
                File.Delete(path);
                File.Move(tmp, path);
                Console.WriteLine("{0}: {1} stubs", asm.MainModule.Name, n);
                changed += n;
            }
        }
        Console.WriteLine("{0} stubs applied", changed);
        return 0;
    }

    // Points references to UnityEngine types that only the Android UnityEngine.dll has at AndroidShim.dll.
    static int RetargetToShim(ModuleDefinition mod, AssemblyDefinition shim)
    {
        var shimTypes = new HashSet<string>(shim.MainModule.Types.Select(t => t.FullName));
        AssemblyNameReference shimRef = null;
        int n = 0;
        foreach (var tr in mod.GetTypeReferences())
        {
            if (tr.DeclaringType != null || ScopeName(tr) != "UnityEngine" || !shimTypes.Contains(tr.FullName)) continue;
            if (shimRef == null)
            {
                shimRef = mod.AssemblyReferences.FirstOrDefault(a => a.Name == shim.Name.Name);
                if (shimRef == null)
                {
                    shimRef = new AssemblyNameReference(shim.Name.Name, shim.Name.Version);
                    mod.AssemblyReferences.Add(shimRef);
                }
            }
            tr.Scope = shimRef;
            n++;
        }
        return n;
    }
}

// The Android-only code paths, replaced by the behaviour the game has when they are unavailable.
static class Stubs
{
    // type full name -> method name -> replacement body kind
    // "ret" = return default value (false / null / 0 / no-op), "true" = return true
    static readonly Dictionary<string, Dictionary<string, string>> Bodies = new Dictionary<string, Dictionary<string, string>>();

    public static void Add(string type, string method, string body)
    {
        Dictionary<string, string> m;
        if (!Bodies.TryGetValue(type, out m)) Bodies[type] = m = new Dictionary<string, string>();
        m[method] = body;
    }

    public static int Apply(ModuleDefinition mod)
    {
        int n = 0;
        foreach (var t in mod.GetTypes())
        {
            Dictionary<string, string> m;
            if (!Bodies.TryGetValue(t.FullName, out m)) continue;
            foreach (var md in t.Methods)
            {
                string kind;
                if (!md.HasBody || !m.TryGetValue(md.Name, out kind) && !m.TryGetValue("*", out kind)) continue;
                if (md.IsConstructor) continue;
                ReplaceBody(md, kind);
                n++;
            }
        }
        return n;
    }

    static void ReplaceBody(MethodDefinition md, string kind)
    {
        var body = md.Body;
        body.Instructions.Clear();
        body.ExceptionHandlers.Clear();
        body.Variables.Clear();
        body.InitLocals = true;
        var il = body.GetILProcessor();
        var rt = md.ReturnType;
        foreach (var prm in md.Parameters)
        {
            if (prm.IsOut && prm.ParameterType is ByReferenceType)
            {
                var et = ((ByReferenceType)prm.ParameterType).ElementType;
                il.Emit(OpCodes.Ldarg, prm);
                il.Emit(OpCodes.Initobj, et);
            }
        }
        if (rt.FullName == "System.Void") { il.Emit(OpCodes.Ret); return; }
        if (kind == "true" && rt.FullName == "System.Boolean") { il.Emit(OpCodes.Ldc_I4_1); il.Emit(OpCodes.Ret); return; }
        if (rt.IsValueType || rt.IsGenericParameter)
        {
            var v = new VariableDefinition(rt);
            body.Variables.Add(v);
            il.Emit(OpCodes.Ldloca, v);
            il.Emit(OpCodes.Initobj, rt);
            il.Emit(OpCodes.Ldloc, v);
            il.Emit(OpCodes.Ret);
            return;
        }
        il.Emit(OpCodes.Ldnull);
        il.Emit(OpCodes.Ret);
    }
}
