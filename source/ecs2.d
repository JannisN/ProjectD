module ecs2;

import utils;
import functions;

// für dynamisch: sortierte liste
// initial length soll standardmässig in ECSEntity auf 0 initialisiert werden

struct ECSEntity(
    StaticComponents,
    StaticGeneralUpdates,
    StaticSpecificUpdates,
    StaticAddUpdates,
    StaticViews
) {
    size_t[StaticComponents.length] staticComponents = size_t.max;
    size_t[StaticGeneralUpdates.length] staticGeneralUpdates = size_t.max;
    size_t[StaticSpecificUpdates.length] staticSpecificUpdates = size_t.max;
    size_t[StaticAddUpdates.length] staticAddUpdates = size_t.max;
    size_t[StaticViews.length] staticViews = size_t.max;
}

struct VirtualEntity(ECS) {
    ECS* ecs;
    size_t entityId;
    auto ref add(Component)() {
        ecs.addComponent!Component(entityId);
        return this;
    }
    auto ref add(Component)(lazy Component component) {
        ecs.addComponent!Component(entityId, component);
        return this;
    }
    auto ref remove(Component)() {
        ecs.removeComponent!Component(entityId);
        return this;
    }
    auto ref get(Component)() if (
        findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq).length == 0 &&
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponents).length == 0
    ) {
        return ecs.getComponents!Component()[ecs.getComponentId!Component()];
    }
    auto get(Component)() if (
        findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq).length > 0 ||
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponents).length > 0
    ) {
        return VirtualComponent!(ECS, Component)(&this);
    }
    auto ref getForced(Component)() {
        return ecs.getComponents!Component()[ecs.getComponentId!Component()];
    }
}

struct VirtualComponent(ECS, Component) {
    VirtualEntity!ECS* virtualEntity;
    auto ref opAssign(lazy Component component) {
        virtualEntity.remove!Component;
        virtualEntity.add!Component(component);
        return this;
    }
	@property ref auto getComponent() {
        return VirtualEntity.getForced!Component();
	}
    alias getComponent this;
    template opDispatch(string member) {
        @property auto opDispatch() {
            return VirtualMember!(ECS, Component, member)(&this);
        }
    }
}

struct VirtualMember(ECS, Component, string member) {
    VirtualComponent!(ECS, Component)* virtualComponent;
    auto ref opAssign(T)(lazy T t) {
        getMember = t;
        static if (findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq).length > 0) {

        }
        // für specific updates wirds komplizierter: man muss testen ob vorherige member
        // im tree in specific updates stehen
        // möglicherweise für static am einfachsten wenn man die id von den vorherigen listen mitgibt als template
        return this;
    }
	template opDispatch(string member2) {
		@property auto ref opDispatch() {
			return VirtualMember!(ECS, Component, member ~ "." ~ member2)(virtualComponent);
		}
	}
	@property ref auto getMember() {
        mixin("return virtualComponent.getComponent()." ~ member ~ ";");
	}
    alias getMember this;
}

struct ECSConfig {
    bool compact;
}

// todo: variablen in static umbenennen wo sinn macht, asserts verwenden wenn im debug modus
struct DynamicECS(
    alias BaseVector,
    StaticComponents,
    StaticGeneralUpdates,
    StaticSpecificUpdates,
    StaticAddUpdates,
    StaticRemoveUpdates,
    StaticViews,
    ECSConfig config
) {
    alias TemplateGeneralUpdates = StaticGeneralUpdates;
    alias TemplateSpecificUpdates = StaticSpecificUpdates;
    alias ExtractComponent(T) = T.TypeSeq[0];
    alias SpecificUpdatesOnlyComponents = ApplyTypeSeq!(ExtractComponent, StaticSpecificUpdates.TypeSeq);
    alias ECSType = DynamicECS!(
        BaseVector,
        StaticComponents,
        StaticGeneralUpdates,
        StaticSpecificUpdates,
        StaticAddUpdates,
        StaticRemoveUpdates,
        StaticViews,
        config
    );
    alias Entity = ECSEntity!(
        StaticComponents,
        StaticGeneralUpdates,
        StaticSpecificUpdates,
        StaticAddUpdates,
        StaticViews
    );
    static if (config.compact) {
        alias ToList(T) = CompactVectorList!(BaseVector, T);
    } else {
        alias ToList(T) = VectorList!(BaseVector, T);
    }
    alias ComponentLists = ApplyTypeSeq!(ToList, StaticComponents.TypeSeq);
    alias RemoveLists = ApplyTypeSeq!(ToList, StaticRemoveUpdates.TypeSeq);

    VectorList!(BaseVector, Entity) entities;
    ComponentLists componentLists;
    // speichert zu welchem entity ein component gehört
    ToList!size_t[ComponentLists.length] componentEntityIds;
    VectorList!(BaseVector, size_t)[StaticAddUpdates.length] addUpdates;
    RemoveLists removeUpdates;
    static if (config.compact) {
        VectorList!(BaseVector, Moved)[StaticRemoveUpdates.length] movedComponents;
    }
    VectorList!(BaseVector, size_t)[StaticViews.length] views;

    size_t getComponentId(Component)() {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        return componentId;
    }
    auto ref getComponents(Component)() {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        return componentLists[componentId];
    }
    auto ref getAddUpdateList(Component)() {
        return addUpdates[findTypes!(Component, StaticAddUpdates.TypeSeq)[0]];
    }
    auto ref getRemoveUpdateList(Component)() {
        return removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]];
    }
    auto ref getMovedComponentsList(Component)() if (config.compact) {
        return movedComponents[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]];
    }
    auto ref getView(Components...)() {
        return views[findView!(StaticViews, Components)];
    }
    VirtualEntity!ECSType add() {
        size_t id = entities.addId(Entity());
        return VirtualEntity!ECSType(&this, id);
    }
    void addComponent(Component)(size_t id) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = componentLists[componentId].addId();
        componentEntityIds[componentId].addId(id);
        entities[id].staticComponents[componentId] = componentEntityId;
        updateAddUpdateList!Component(id);
        updateViews!(Component, true)(id);
    }
    void addComponent(Component)(size_t id, lazy Component component) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = componentLists[componentId].addId(component);
        componentEntityIds[componentId].addId(id);
        entities[id].staticComponents[componentId] = componentEntityId;
        updateAddUpdateList!Component(id);
        updateViews!(Component, true)(id);
    }
    void removeComponent(Component)(size_t id) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = entities[id].staticComponents[componentId];
        componentEntityIds[componentId].removeById(componentEntityId);
        static if (findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0) {
            size_t removedId = removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].addId();
            Component dummy;
            memcpy(
                cast(void*)&removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]][removedId],
                cast(void*)&componentLists[componentId][componentEntityId],
                Component.sizeof
            );
            memcpy(cast(void*)&componentLists[componentId][componentEntityId], cast(void*)&dummy, Component.sizeof);
        }
        static if (config.compact) {
            auto moved = componentLists[componentId].remove(componentEntityId);
            if (moved.oldId != moved.newId) {
                entities[componentEntityIds[componentId][moved.newId]].staticComponents[componentId] = moved.newId;
            }
            static if (findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0) {
                movedComponents[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].add(moved);
            }
        } else {
            componentLists[componentId].remove(componentEntityId);
        }
        entities[id].staticComponents[componentId] = size_t.max;
        static if (findTypes!(Component, StaticAddUpdates.TypeSeq).length > 0) {
            enum size_t typeId = findTypes!(Component, StaticAddUpdates.TypeSeq)[0];
            size_t addUpdatesId = entities[id].staticAddUpdates[typeId];
            if (addUpdatesId != size_t.max) {
                addUpdates[typeId].removeById(cast(size_t)addUpdatesId);
                entities[id].staticAddUpdates[typeId] = size_t.max;
            }
        }
        updateViews!(Component, false)(id);
    }
    void updateAddUpdateList(Component)(size_t id) {
        static if (findTypes!(Component, StaticAddUpdates.TypeSeq).length > 0) {
            enum size_t typeId = findTypes!(Component, StaticAddUpdates.TypeSeq)[0];
            size_t addUpdatesId = addUpdates[typeId].addId(id);
            entities[id].staticAddUpdates[typeId] = addUpdatesId;
        }
    }
    void updateViews(Component, bool added)(size_t id) {
        static foreach (typeId, View; StaticViews.TypeSeq) {
            static if (findTypes!(Component, View.TypeSeq).length > 0) {
                bool partOfView = true;
                static foreach (ViewEntry; View.TypeSeq) {
                    if (entities[id].staticComponents[findTypes!(ViewEntry, StaticComponents.TypeSeq)[0]] == size_t.max) {
                        partOfView = false;
                    }
                }
                if (partOfView) {
                    static if (added) {
                        size_t viewId = views[typeId].addId(id);
                        entities[id].staticViews[typeId] = viewId;
                    } else {
                        views[typeId].remove(id);
                        entities[id].staticViews[typeId] = size_t.max;
                    }
                }
            }
        }
    }
}

template findView(U, T...) {
	size_t findViewImpl() {
		static foreach (i, TS; U.TypeSeq) {
			static if (TS.TypeSeq.length == T.length) {
				bool found = true;
				static foreach (Type; TS.TypeSeq) {
					static if (countType!(Type, T) == 0) {
						found = false;
					}
				}
				if (found) {
					return i;
				}
			}
		}
		assert(false, "View not found");
	}
	enum size_t findView = findViewImpl();
}

unittest {
    import std.stdio;
    alias PartialVec(T) = PartialVector!(T, 100);
    DynamicECS!(
        PartialVec,//Vector
        TypeSeqStruct!(int, double),
        TypeSeqStruct!(),
        TypeSeqStruct!(),
        TypeSeqStruct!(int),
        TypeSeqStruct!(int),
        TypeSeqStruct!(
            TypeSeqStruct!(int, double)
        ),
        ECSConfig(true)
    ) ecs;
    auto entity = ecs.add();
    entity.add!int(3);
    entity.get!int() = 8;
    writeln("view size: ", ecs.getView!(int, double).length);
    entity.add!double(3.0);
    ecs.add().add!int(10);
    writeln("view size: ", ecs.getView!(int, double).length);
    foreach (i; ecs.getComponents!int()) {
        writeln(i);
    }
    writeln("addUpdateList length: ", ecs.getAddUpdateList!int().length);
    entity.remove!int();
    writeln("addUpdateList length: ", ecs.getAddUpdateList!int().length);
    writeln("removeUpdateList length: ", ecs.getRemoveUpdateList!int().length);
    foreach (e; ecs.getRemoveUpdateList!int()) {
        writeln(e);
    }
    foreach (e; ecs.getMovedComponentsList!int()) {
        writeln("from, to: ", e.oldId, " ", e.newId);
    }
    foreach (i; ecs.getComponents!int()) {
        writeln(i);
    }
}
