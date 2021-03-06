package org.jruby.ir.targets;

import org.jruby.RubyClass;
import org.jruby.internal.runtime.methods.DynamicMethod;
import org.jruby.ir.runtime.IRRuntimeHelpers;
import org.jruby.runtime.Block;
import org.jruby.runtime.CallType;
import org.jruby.runtime.Helpers;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.callsite.CacheEntry;
import org.jruby.util.JavaNameMangler;
import org.objectweb.asm.Handle;
import org.objectweb.asm.Opcodes;

import java.lang.invoke.CallSite;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.lang.invoke.SwitchPoint;

import static org.jruby.ir.runtime.IRRuntimeHelpers.splatArguments;
import static org.jruby.util.CodegenUtils.p;
import static org.jruby.util.CodegenUtils.sig;

/**
* Created by headius on 10/23/14.
*/
public abstract class ResolvedSuperInvokeSite extends SelfInvokeSite {
    protected final String superName;
    protected final boolean[] splatMap;

    public ResolvedSuperInvokeSite(MethodType type, String superName, String splatmapString) {
        super(type, superName, CallType.SUPER);

        this.superName = superName;
        this.splatMap = IRRuntimeHelpers.decodeSplatmap(splatmapString);
    }

    public static final Handle BOOTSTRAP = new Handle(Opcodes.H_INVOKESTATIC, p(ResolvedSuperInvokeSite.class), "bootstrap", sig(CallSite.class, MethodHandles.Lookup.class, String.class, MethodType.class, String.class));

    public static CallSite bootstrap(MethodHandles.Lookup lookup, String name, MethodType type, String splatmapString) {
        String[] targetAndMethod = name.split(":");
        String superName = JavaNameMangler.demangleMethodName(targetAndMethod[1]);

        InvokeSite site;

        switch (targetAndMethod[0]) {
            case "invokeInstanceSuper":
                site = new InstanceSuperInvokeSite(type, superName, splatmapString);
                break;
            case "invokeClassSuper":
                site = new ClassSuperInvokeSite(type, superName, splatmapString);
                break;
            case "invokeUnresolvedSuper":
                site = new UnresolvedSuperInvokeSite(type, superName, splatmapString);
                break;
            case "invokeZSuper":
                site = new ZSuperInvokeSite(type, superName, splatmapString);
                break;
            default:
                throw new RuntimeException("invalid super call: " + name);
        }

        return InvokeSite.bootstrap(site, lookup);
    }

    public IRubyObject invoke(ThreadContext context, IRubyObject caller, IRubyObject self, RubyClass definingModule, IRubyObject[] args, Block block) throws Throwable {
        // TODO: mostly copy of org.jruby.ir.targets.InvokeSite because of different target class logic

        RubyClass selfClass = pollAndGetClass(context, self);
        RubyClass superClass = getSuperClass(definingModule);
        SwitchPoint switchPoint = (SwitchPoint) superClass.getInvalidator().getData();
        CacheEntry entry = superClass.searchWithCache(methodName);
        DynamicMethod method = entry.method;

        if (methodMissing(entry, caller)) {
            return callMethodMissing(entry, callType, context, self, methodName, args, block);
        }

        MethodHandle mh = getHandle(superClass, this, method);

        updateInvocationTarget(mh, self, selfClass, entry, switchPoint);

        return method.call(context, self, superClass, methodName, args, block);
    }

    public IRubyObject fail(ThreadContext context, IRubyObject caller, IRubyObject self, RubyClass definingModule, IRubyObject[] args, Block block) throws Throwable {
        // TODO: get rid of caller

        context.callThreadPoll();

        RubyClass superClass = getSuperClass(definingModule);
        String name = methodName;
        CacheEntry entry = cache;

        if (entry.typeOk(superClass)) {
            return entry.method.call(context, self, superClass, name, splatArguments(args, splatMap), block);
        }

        entry = superClass != null ? superClass.searchWithCache(name) : CacheEntry.NULL_CACHE;

        DynamicMethod method = entry.method;

        if (method.isUndefined()) {
            return Helpers.callMethodMissing(context, self, method.getVisibility(), name, callType, splatArguments(args, splatMap), block);
        }

        cache = entry;

        return method.call(context, self, superClass, name, splatArguments(args, splatMap), block);
    }

    protected abstract RubyClass getSuperClass(RubyClass definingModule);
}