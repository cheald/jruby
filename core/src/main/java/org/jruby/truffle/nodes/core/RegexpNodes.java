/*
 * Copyright (c) 2013, 2014 Oracle and/or its affiliates. All rights reserved. This
 * code is released under a tri EPL/GPL/LGPL license. You can use it,
 * redistribute it and/or modify it under the terms of the:
 *
 * Eclipse Public License version 1.0
 * GNU General Public License version 2
 * GNU Lesser General Public License version 2.1
 */
package org.jruby.truffle.nodes.core;

import com.oracle.truffle.api.source.*;
import com.oracle.truffle.api.dsl.*;
import com.oracle.truffle.api.frame.VirtualFrame;
import org.jruby.truffle.nodes.dispatch.DispatchHeadNode;
import org.jruby.truffle.runtime.*;
import org.jruby.truffle.runtime.core.*;
import org.jruby.util.ByteList;

@CoreClass(name = "Regexp")
public abstract class RegexpNodes {

    @CoreMethod(names = "==", required = 1)
    public abstract static class EqualNode extends CoreMethodNode {

        public EqualNode(RubyContext context, SourceSection sourceSection) {
            super(context, sourceSection);
        }

        public EqualNode(EqualNode prev) {
            super(prev);
        }

        @Specialization
        public boolean equal(RubyRegexp a, RubyRegexp b) {
            notDesignedForCompilation();

            return a.equals(b);
        }

    }

    @CoreMethod(names = "===", required = 1)
    public abstract static class ThreeEqualNode extends CoreMethodNode {

        public ThreeEqualNode(RubyContext context, SourceSection sourceSection) {
            super(context, sourceSection);
        }

        public ThreeEqualNode(ThreeEqualNode prev) {
            super(prev);
        }

        @Specialization
        public Object match(RubyRegexp regexp, RubyString string) {
            notDesignedForCompilation();

            return regexp.matchOperator(string.toString()) != getContext().getCoreLibrary().getNilObject();
        }

    }

    @CoreMethod(names = "=~", required = 1)
    public abstract static class MatchOperatorNode extends CoreMethodNode {

        @Child protected DispatchHeadNode matchNode;

        public MatchOperatorNode(RubyContext context, SourceSection sourceSection) {
            super(context, sourceSection);
            matchNode = new DispatchHeadNode(context);
        }

        public MatchOperatorNode(MatchOperatorNode prev) {
            super(prev);
            matchNode = prev.matchNode;
        }

        @Specialization
        public Object match(RubyRegexp regexp, RubyString string) {
            notDesignedForCompilation();

            return regexp.matchOperator(string.toString());
        }

        @Specialization
        public Object match(VirtualFrame frame, RubyRegexp regexp, RubyBasicObject other) {
            notDesignedForCompilation();

            return matchNode.call(frame, other, "=~", null, regexp);
        }

    }

    @CoreMethod(names = "!~", required = 1)
    public abstract static class NotMatchOperatorNode extends CoreMethodNode {

        public NotMatchOperatorNode(RubyContext context, SourceSection sourceSection) {
            super(context, sourceSection);
        }

        public NotMatchOperatorNode(NotMatchOperatorNode prev) {
            super(prev);
        }

        @Specialization
        public Object match(RubyRegexp regexp, RubyString string) {
            notDesignedForCompilation();

            return regexp.matchOperator(string.toString()) == getContext().getCoreLibrary().getNilObject();
        }

    }

    @CoreMethod(names = "escape", onSingleton = true, required = 1)
    public abstract static class EscapeNode extends CoreMethodNode {

        public EscapeNode(RubyContext context, SourceSection sourceSection) {
            super(context, sourceSection);
        }

        public EscapeNode(EscapeNode prev) {
            super(prev);
        }

        @Specialization
        public RubyString sqrt(RubyString pattern) {
            notDesignedForCompilation();

            return getContext().makeString(org.jruby.RubyRegexp.quote19(new ByteList(pattern.getBytes()), true).toString());
        }

    }

    @CoreMethod(names = "initialize", required = 1)
    public abstract static class InitializeNode extends CoreMethodNode {

        public InitializeNode(RubyContext context, SourceSection sourceSection) {
            super(context, sourceSection);
        }

        public InitializeNode(InitializeNode prev) {
            super(prev);
        }

        @Specialization
        public RubyNilClass initialize(RubyRegexp regexp, RubyString string) {
            notDesignedForCompilation();

            regexp.initialize(this, string.toString());
            return getContext().getCoreLibrary().getNilObject();
        }

    }

    @CoreMethod(names = "match", required = 1)
    public abstract static class MatchNode extends CoreMethodNode {

        public MatchNode(RubyContext context, SourceSection sourceSection) {
            super(context, sourceSection);
        }

        public MatchNode(MatchNode prev) {
            super(prev);
        }

        @Specialization
        public Object match(RubyRegexp regexp, RubyString string) {
            notDesignedForCompilation();

            return regexp.match(string);
        }

    }

}
