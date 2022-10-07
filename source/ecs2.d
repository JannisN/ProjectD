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
    StaticViews,
    ECSConfig config
) {
    size_t[StaticComponents.length] staticComponents = size_t.max;
    size_t[StaticGeneralUpdates.length] staticGeneralUpdates = size_t.max;
    size_t[StaticSpecificUpdates.length] staticSpecificUpdates = size_t.max;
    size_t[StaticAddUpdates.length] staticAddUpdates = size_t.max;
    size_t[StaticViews.length] staticViews = size_t.max;
    static if (config.dynamicComponents) {
        alias VectorListType(T) = VectorList!(Vector, T);
        OrderedList!(VectorListType, DynamicEntityComponent, DynamicEntityComponent.sortFunc) dynamicComponents;
    }
}

struct DynamicEntityComponent {
    size_t structId;
    size_t componentId;
    static bool sortFunc(ref DynamicEntityComponent dec1, ref DynamicEntityComponent dec2) {
        return dec1.structId < dec2.structId;
    }
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
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponents).length == 0 &&
        findTypes!(Component, ECS.TemplateGeneralUpdatesMultiple.TypeSeq).length == 0 &&
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponentsMultiple).length == 0
    ) {
        version (Debug) {
            assert(ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return ecs.getComponents!Component()[ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()]];
    }
    auto get(Component)() if (
        findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq).length > 0 ||
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponents).length > 0 ||
        findTypes!(Component, ECS.TemplateGeneralUpdatesMultiple.TypeSeq).length > 0 ||
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponentsMultiple).length > 0
    ) {
        version (Debug) {
            assert(ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return VirtualComponent!(ECS, Component)(&this);
    }
    auto ref getForced(Component)() {
        version (Debug) {
            assert(ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return ecs.getComponents!Component()[ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()]];
    }
}

struct VirtualComponent(ECS, Component) {
    VirtualEntity!ECS* virtualEntity;
    auto ref opAssign(lazy Component component) {
        // vlt ist hier remove, add doch besser da man dann weiss dass das ganze objekt neu ist
        // dann müsste aber auch ein virtualcomponent zurückgegeben werden bei virtualentity falls es eine add/remove list gibt
        // erstmal so lassen... man kann sonst einfach manuell zuerst entfernen und wieder hinzufügen
        //virtualEntity.remove!Component;
        //virtualEntity.add!Component(component);
        getComponent() = component;
        static if (findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq).length > 0) {
            if (virtualEntity.ecs.entities[virtualEntity.entityId].staticGeneralUpdates[findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq)[0]] == size_t.max) {
                size_t updateId = virtualEntity.ecs.getGeneralUpdateList!Component().addId(virtualEntity.entityId);
                virtualEntity.ecs.entities[virtualEntity.entityId].staticGeneralUpdates[findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq)[0]] = updateId;
            }
        }
        static if (findTypes!(Component, ECS.TemplateGeneralUpdatesMultiple.TypeSeq).length > 0) {
            virtualEntity.ecs.getGeneralUpdateListMultiple!Component().add(virtualEntity.entityId);
        }
        return this;
    }
	@property ref auto getComponent() {
        return virtualEntity.getForced!Component();
	}
    alias getComponent this;
    template opDispatch(string member) {
        @property auto opDispatch() {
            auto virtualComponent = &this;
            static if (findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq).length > 0 && findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member,
                        TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq)[0]),
                        TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent));
            } else static if (findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member, TypeSeqStruct!(), TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent));
            } else static if (findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member, TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq)[0]), TypeSeqStruct!())(virtualComponent));
            } else {
                return (VirtualMember!(ECS, Component, member, TypeSeqStruct!(), TypeSeqStruct!())(virtualComponent));
            }
        }
        @property auto opDispatch(T)(lazy T t) {
            auto virtualComponent = &this;
            static if (findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq).length > 0 && findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member,
                        TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq)[0]),
                        TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent) = t);
            } else static if (findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member, TypeSeqStruct!(), TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent) = t);
            } else static if (findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member, TypeSeqStruct!(findTypes!(TypeSeqStruct!(Component, member), ECS.TemplateSpecificUpdates.TypeSeq)[0]), TypeSeqStruct!())(virtualComponent) = t);
            } else {
                return (VirtualMember!(ECS, Component, member, TypeSeqStruct!(), TypeSeqStruct!())(virtualComponent) = t);
            }
        }
    }
}

struct VirtualMember(ECS, Component, string member, StaticSpecificIndices, StaticSpecificIndicesMultiple) {
    VirtualComponent!(ECS, Component)* virtualComponent;
    auto ref opAssign(T)(lazy T t) {
        getMember = t;
        static if (findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq).length > 0) {
            if (virtualComponent.virtualEntity.ecs.entities[virtualComponent.virtualEntity.entityId].staticGeneralUpdates[findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq)[0]] == size_t.max) {
                size_t updateId = virtualComponent.virtualEntity.ecs.getGeneralUpdateList!Component().addId(virtualComponent.virtualEntity.entityId);
                virtualComponent.virtualEntity.ecs.entities[virtualComponent.virtualEntity.entityId].staticGeneralUpdates[findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq)[0]] = updateId;
            }
        }
        static if (findTypes!(Component, ECS.TemplateGeneralUpdatesMultiple.TypeSeq).length > 0) {
            virtualComponent.virtualEntity.ecs.getGeneralUpdateListMultiple!Component().add(virtualComponent.virtualEntity.entityId);
        }
        static foreach (size_t i; StaticSpecificIndices.TypeSeq) {
            if (virtualComponent.virtualEntity.ecs.entities[virtualComponent.virtualEntity.entityId].staticSpecificUpdates[i] == size_t.max) {
                size_t updateId = virtualComponent.virtualEntity.ecs.specificUpdates[i].addId(virtualComponent.virtualEntity.entityId);
                virtualComponent.virtualEntity.ecs.entities[virtualComponent.virtualEntity.entityId].staticSpecificUpdates[i] = updateId;
            }
        }
        static foreach (size_t i; StaticSpecificIndicesMultiple.TypeSeq) {
            virtualComponent.virtualEntity.ecs.specificUpdatesMultiple[i].add(virtualComponent.virtualEntity.entityId);
        }
        return this;
    }
	template opDispatch(string member2) {
		@property auto ref opDispatch() {
            static if (findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq).length > 0 && findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return VirtualMember!(ECS, Component, member ~ "." ~ member2,
                        TypeSeqStruct!(StaticSpecificIndices.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq)[0]),
                        TypeSeqStruct!(StaticSpecificIndicesMultiple.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent);
            } else static if (findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return VirtualMember!(ECS, Component, member ~ "." ~ member2, StaticSpecificIndices, TypeSeqStruct!(StaticSpecificIndicesMultiple.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent);
            } else static if (findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq).length > 0) {
                return VirtualMember!(ECS, Component, member ~ "." ~ member2, TypeSeqStruct!(StaticSpecificIndices.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq)[0]), StaticSpecificIndicesMultiple)(virtualComponent);
            } else {
                return VirtualMember!(ECS, Component, member ~ "." ~ member2, StaticSpecificIndices, StaticSpecificIndicesMultiple)(virtualComponent);
            }
		}
		@property auto ref opDispatch(T)(lazy T t) {
            static if (findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq).length > 0 && findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member ~ "." ~ member2,
                        TypeSeqStruct!(StaticSpecificIndices.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq)[0]),
                        TypeSeqStruct!(StaticSpecificIndicesMultiple.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent) = t);
            } else static if (findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member ~ "." ~ member2, StaticSpecificIndices, TypeSeqStruct!(StaticSpecificIndicesMultiple.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdatesMultiple.TypeSeq)[0]))(virtualComponent) = t);
            } else static if (findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq).length > 0) {
                return (VirtualMember!(ECS, Component, member ~ "." ~ member2, TypeSeqStruct!(StaticSpecificIndices.TypeSeq, findTypes!(TypeSeqStruct!(Component, member ~ "." ~ member2), ECS.TemplateSpecificUpdates.TypeSeq)[0]), StaticSpecificIndicesMultiple)(virtualComponent) = t);
            } else {
                return (VirtualMember!(ECS, Component, member ~ "." ~ member2, StaticSpecificIndices, StaticSpecificIndicesMultiple)(virtualComponent) = t);
            }
		}
	}
	@property ref auto getMember() {
        mixin("return virtualComponent.getComponent()." ~ member ~ ";");
	}
    alias getMember this;
}

struct ECSConfig {
    bool compact;
    bool dynamicComponents;
}

struct DynamicComponentStruct {
    string s;
    size_t id;
    // vlt für debug später
    //size_t size;
    static bool sortFunc(ref DynamicComponentStruct dcs1, ref DynamicComponentStruct dcs2) {
        if (dcs1.s.length == 0 || dcs2.s.length == 0) {
            return true;
        }
        return strcmp(dcs1.s.ptr, dcs2.s.ptr) < 0;
    }
}

struct DynamicECS(
    alias BaseVector,
    StaticComponents,
    StaticGeneralUpdates,
    StaticSpecificUpdates,
    StaticGeneralUpdatesMultiple,
    StaticSpecificUpdatesMultiple,
    StaticAddUpdates,
    StaticRemoveUpdates,
    StaticViews,
    ECSConfig config
) {
    alias TemplateGeneralUpdates = StaticGeneralUpdates;
    alias TemplateSpecificUpdates = StaticSpecificUpdates;
    alias TemplateGeneralUpdatesMultiple = StaticGeneralUpdatesMultiple;
    alias TemplateSpecificUpdatesMultiple = StaticSpecificUpdatesMultiple;
    alias TemplateConfig = config;
    alias ExtractComponent(T) = T.TypeSeq[0];
    alias SpecificUpdatesOnlyComponents = ApplyTypeSeq!(ExtractComponent, StaticSpecificUpdates.TypeSeq);
    alias SpecificUpdatesOnlyComponentsMultiple = ApplyTypeSeq!(ExtractComponent, StaticSpecificUpdatesMultiple.TypeSeq);
    alias ECSType = DynamicECS!(
        BaseVector,
        StaticComponents,
        StaticGeneralUpdates,
        StaticSpecificUpdates,
        StaticGeneralUpdatesMultiple,
        StaticSpecificUpdatesMultiple,
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
        StaticViews,
        config
    );
    static if (config.compact) {
        alias ToList(T) = CompactVectorList!(BaseVector, T);
    } else {
        alias ToList(T) = VectorList!(BaseVector, T);
    }
    alias ComponentLists = ApplyTypeSeq!(ToList, StaticComponents.TypeSeq);
    alias RemoveLists = ApplyTypeSeq!(ToList, StaticRemoveUpdates.TypeSeq);

    // static -------------------
    VectorList!(BaseVector, Entity) entities;
    ComponentLists componentLists;
    // speichert zu welchem entity ein component gehört
    ToList!size_t[ComponentLists.length] componentEntityIds;
    VectorList!(BaseVector, size_t)[StaticGeneralUpdates.length] generalUpdates;
    VectorList!(BaseVector, size_t)[StaticSpecificUpdates.length] specificUpdates;
    VectorList!(BaseVector, size_t)[StaticGeneralUpdatesMultiple.length] generalUpdatesMultiple;
    VectorList!(BaseVector, size_t)[StaticSpecificUpdatesMultiple.length] specificUpdatesMultiple;
    VectorList!(BaseVector, size_t)[StaticAddUpdates.length] addUpdates;
    RemoveLists removeUpdates;
    static if (config.compact) {
        VectorList!(BaseVector, Moved)[StaticRemoveUpdates.length] movedComponents;
    }
    VectorList!(BaseVector, size_t)[StaticViews.length] views;

    // dynamic ------------------
    alias VectorListType(T) = VectorList!(Vector, T);
    OrderedList!(VectorListType, DynamicComponentStruct, DynamicComponentStruct.sortFunc) dynamicComponentStructs;
    ToList!Unknown dynamicComponentLists;
    // speichert zu welchem entity ein component gehört
    ToList!(ToList!size_t) dynamicComponentEntityIds;

    size_t getComponentId(Component)() {
        return findTypes!(Component, StaticComponents.TypeSeq)[0];
    }
    auto ref getComponents(Component)() {
        return componentLists[findTypes!(Component, StaticComponents.TypeSeq)[0]];
    }
    auto ref getGeneralUpdateList(Component)() {
        return generalUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]];
    }
    auto ref getSpecificUpdateList(Component, string member)() {
        return specificUpdates[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdates.TypeSeq)[0]];
    }
    auto ref getGeneralUpdateListMultiple(Component)() {
        return generalUpdatesMultiple[findTypes!(Component, StaticGeneralUpdatesMultiple.TypeSeq)[0]];
    }
    auto ref getSpecificUpdateListMultiple(Component, string member)() {
        return specificUpdatesMultiple[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdatesMultiple.TypeSeq)[0]];
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
        version (Debug) {
            assert(entities[id].staticComponents[componentId] != size_t.max, "Entity does not have component");
        }
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
                static if (findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0) {
                    movedComponents[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].add(moved);
                }
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

struct TestStruct {
    int testInt;
}

unittest {
    import std.stdio;
    alias PartialVec(T) = PartialVector!(T, 100);
    DynamicECS!(
        PartialVec,//Vector
        TypeSeqStruct!(int, double, TestStruct),
        TypeSeqStruct!(int),
        TypeSeqStruct!(
            TypeSeqStruct!(TestStruct, "testInt")
        ),
        TypeSeqStruct!(int),
        TypeSeqStruct!(
            TypeSeqStruct!(TestStruct, "testInt")
        ),
        TypeSeqStruct!(int),
        TypeSeqStruct!(int),
        TypeSeqStruct!(
            TypeSeqStruct!(int, double)
        ),
        ECSConfig(true, true)
    ) ecs;
    auto entity = ecs.add();
    entity.add!int(3);
    entity.get!int() = 8;
    foreach (size_t e; ecs.getGeneralUpdateList!int()) {
        writeln("index of updates: ", e);
    }
    entity.get!int() = 7;
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
    entity.add!TestStruct();
    entity.get!TestStruct.testInt = 1;
    foreach (size_t e; ecs.getSpecificUpdateList!(TestStruct, "testInt")()) {
        writeln("index of TestStruct, testInt updates: ", e);
    }
    foreach (size_t e; ecs.getGeneralUpdateList!int()) {
        writeln("index of updates: ", e);
    }
    foreach (size_t e; ecs.getGeneralUpdateListMultiple!int()) {
        writeln("index of updates multiple: ", e);
    }

    Vector!size_t toSort = Vector!size_t(8);
    toSort[0] = 12;
    toSort[1] = 10;
    toSort[2] = 5;
    toSort[3] = 2;
    toSort[4] = 1;
    toSort.sort!checkSort();
    foreach (size_t i; toSort) {
        write(i, " ");
    }
    writeln();

    alias TestType(T) = VectorList!(Vector, T);
    OrderedList!(TestType, size_t, checkSort) ol;
    ol.addNoSort(3).addNoSort(2).addNoSort(1).sort();
    foreach (size_t i; ol) {
        writeln(i);
    }

    ecs.dynamicComponentStructs.addNoSort(DynamicComponentStruct("bla", 3));
    ecs.dynamicComponentStructs.addNoSort(DynamicComponentStruct("zbla", 1));
    ecs.dynamicComponentStructs.addNoSort(DynamicComponentStruct("abla", 2));
    ecs.dynamicComponentStructs.sort();
    foreach (DynamicComponentStruct i; ecs.dynamicComponentStructs) {
        writeln(i.s, " ", i.id);
    }
}

bool checkSort(size_t a, size_t b) {
    return a < b;
}