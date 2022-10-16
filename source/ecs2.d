module ecs2;

import utils;
import functions;

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
        OrderedList!(VectorListType, DynamicEntityComponent) dynamicComponents;
    }
}

struct DynamicEntityComponent {
    size_t structId;
    size_t componentId;
    int opCmp(ref const DynamicEntityComponent dec) const {
        return cast(int)(structId - dec.structId);
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
        ecs.isComponentStatic!Component &&
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
        ecs.isComponentStatic!Component && (
        findTypes!(Component, ECS.TemplateGeneralUpdates.TypeSeq).length > 0 ||
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponents).length > 0 ||
        findTypes!(Component, ECS.TemplateGeneralUpdatesMultiple.TypeSeq).length > 0 ||
        findTypes!(Component, ECS.SpecificUpdatesOnlyComponentsMultiple).length > 0)
    ) {
        version (Debug) {
            assert(ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return VirtualComponent!(ECS, Component)(this);
    }
    auto ref get(Component)() if (!ecs.isComponentStatic!Component) {
        size_t dcs = ecs.dynamicComponentStructs.findIndex(DynamicComponentStruct(Component.stringof));
        DynamicEntityComponent dec = ecs.entities[entityId].dynamicComponents.findUnique(DynamicEntityComponent(dcs));
        return ecs.dynamicComponentLists[ecs.dynamicComponentStructs[dcs].id].get!(ECS.ToList!Component)()[dec.componentId];
    }
    auto ref getForced(Component)() if (ecs.isComponentStatic!Component) {
        version (Debug) {
            assert(ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return ecs.getComponents!Component()[ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()]];
    }
    bool has(Component)() if (ecs.isComponentStatic!Component) {
        return ecs.entities[entityId].staticComponents[ecs.getComponentId!Component()] != size_t.max;
    }
    bool has(Component)() if (!ecs.isComponentStatic!Component) {
        size_t dcs = ecs.dynamicComponentStructs.findIndex(DynamicComponentStruct(Component.stringof));
        size_t index = ecs.entities[entityId].dynamicComponents.findIndex(DynamicEntityComponent(dcs));
        return index != size_t.max;
    }
}

struct VirtualComponent(ECS, Component) {
    VirtualEntity!ECS virtualEntity;
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
    int opCmp(ref const DynamicComponentStruct dcs) const {
        if (s.length == 0 || dcs.s.length == 0) {
            return -1;
        }
        return strcmp(s.ptr, dcs.s.ptr);
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
    ToList!size_t[StaticRemoveUpdates.length] removeIds;
    static if (config.compact) {
        VectorList!(BaseVector, Moved)[StaticRemoveUpdates.length] movedComponents;
    }
    ToList!size_t[StaticViews.length] views;

    // dynamic ------------------
    alias VectorListType(T) = VectorList!(Vector, T);
    OrderedList!(VectorListType, DynamicComponentStruct) dynamicComponentStructs;
    ToList!Unknown dynamicComponentLists;
    // speichert zu welchem entity ein component gehört
    ToList!(ToList!size_t) dynamicComponentEntityIds;
    ToList!(typeof((ToList!size_t).removeById(0)) delegate(size_t)) componentDestructors;

    enum bool isComponentStatic(Component) = (findTypes!(Component, StaticComponents.TypeSeq).length > 0);
    size_t getComponentId(Component)() if (isComponentStatic!Component) {
        return findTypes!(Component, StaticComponents.TypeSeq)[0];
    }
    auto ref getComponents(Component)() if (isComponentStatic!Component) {
        return componentLists[findTypes!(Component, StaticComponents.TypeSeq)[0]];
    }
    auto ref getComponents(Component)() if (!(isComponentStatic!Component)) {
        size_t dcsId = addDynamicComponentStruct!Component();
        size_t dclId = dynamicComponentStructs[dcsId].id;
        return dynamicComponentLists[dclId].get!(ToList!Component)();
    }
    auto ref getGeneralUpdateList(Component)() if (isComponentStatic!Component) {
        return generalUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]];
    }
    void clearGeneralUpdateList(Component)() if (isComponentStatic!Component) {
        foreach (i; generalUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]]) {
            entities[i].staticGeneralUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]] = size_t.max;
        }
        generalUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]].clear();
    }
    bool hasGeneralUpdateList(Component)() {
        return findTypes!(Component, StaticGeneralUpdates.TypeSeq).length > 0;
    }
    auto ref getSpecificUpdateList(Component, string member)() if (isComponentStatic!Component) {
        return specificUpdates[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdates.TypeSeq)[0]];
    }
    void clearSpecificUpdateList(Component, string member)() if (isComponentStatic!Component) {
        foreach (i; specificUpdates[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdates.TypeSeq)[0]]) {
            entities[i].staticSpecificUpdates[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdates.TypeSeq)[0]] = size_t.max;
        }
        specificUpdates[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdates.TypeSeq)[0]].clear();
    }
    bool hasSpecificUpdateList(Component, string member)() {
        return findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdates.TypeSeq).length > 0;
    }
    auto ref getGeneralUpdateListMultiple(Component)() if (isComponentStatic!Component) {
        return generalUpdatesMultiple[findTypes!(Component, StaticGeneralUpdatesMultiple.TypeSeq)[0]];
    }
    void clearGeneralUpdateListMultiple(Component)() if (isComponentStatic!Component) {
        generalUpdatesMultiple[findTypes!(Component, StaticGeneralUpdatesMultiple.TypeSeq)[0]].clear();
    }
    bool hasGeneralUpdateListMultiple(Component)() {
        return findTypes!(Component, StaticGeneralUpdatesMultiple.TypeSeq).length > 0;
    }
    auto ref getSpecificUpdateListMultiple(Component, string member)() if (isComponentStatic!Component) {
        return specificUpdatesMultiple[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdatesMultiple.TypeSeq)[0]];
    }
    void clearSpecificUpdateListMultiple(Component, string member)() if (isComponentStatic!Component) {
        specificUpdatesMultiple[findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdatesMultiple.TypeSeq)[0]].clear();
    }
    bool hasSpecificUpdateListMultiple(Component, string member)() {
        return findTypes!(TypeSeqStruct!(Component, member), StaticSpecificUpdatesMultiple.TypeSeq).length > 0;
    }
    auto ref getAddUpdateList(Component)() if (isComponentStatic!Component) {
        return addUpdates[findTypes!(Component, StaticAddUpdates.TypeSeq)[0]];
    }
    void clearAddUpdateList(Component)() if (isComponentStatic!Component) {
        foreach (i; addUpdates[findTypes!(Component, StaticAddUpdates.TypeSeq)[0]]) {
            entities[i].staticAddUpdates[findTypes!(Component, StaticAddUpdates.TypeSeq)[0]] = size_t.max;
        }
        addUpdates[findTypes!(Component, StaticAddUpdates.TypeSeq)[0]].clear();
    }
    bool hasAddUpdateList(Component)() {
        return findTypes!(Component, StaticAddUpdates.TypeSeq).length > 0;
    }
    auto ref getRemoveUpdateList(Component)() if (isComponentStatic!Component) {
        return removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]];
    }
    auto ref getRemoveIdsList(Component)() if (isComponentStatic!Component) {
        return removeIds[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]];
    }
    void clearRemoveUpdateListMultiple(Component)() if (isComponentStatic!Component) {
        removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].clear();
        removeIds.clear();
    }
    bool hasRemoveUpdateList(Component)() {
        return findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0;
    }
    auto ref getMovedComponentsList(Component)() if (config.compact && isComponentStatic!Component) {
        return movedComponents[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]];
    }
    void clearMovedComponentsList(Component)() if (config.compact && isComponentStatic!Component) {
        movedComponents[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].clear();
    }
    bool hasMovedComponentsList(Component)() {
        return (findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0) && config.compact;
    }
    auto ref getView(Components...)() {
        return views[findView!(StaticViews, Components)];
    }
    VirtualEntity!ECSType add() {
        size_t id = entities.addId(Entity());
        return VirtualEntity!ECSType(&this, id);
    }
    auto getEntity(size_t id) {
        return VirtualEntity!ECSType(&this, id);
    }
    void addComponent(Component)(size_t id) if (isComponentStatic!Component) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = componentLists[componentId].addId();
        componentEntityIds[componentId].addId(id);
        entities[id].staticComponents[componentId] = componentEntityId;
        updateAddUpdateList!Component(id);
        updateViews!(Component, true)(id);
    }
    void addComponent(Component)(size_t id, lazy Component component) if (isComponentStatic!Component) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = componentLists[componentId].addId(component);
        componentEntityIds[componentId].addId(id);
        entities[id].staticComponents[componentId] = componentEntityId;
        updateAddUpdateList!Component(id);
        updateViews!(Component, true)(id);
    }
    void addComponent(Component)(size_t id) if (!(isComponentStatic!Component)) {
        size_t dcsId = addDynamicComponentStruct!Component();
        size_t dclId = dynamicComponentStructs[dcsId].id;
        size_t componentId = dynamicComponentLists[dclId].get!(ToList!Component)().addId();
        dynamicComponentEntityIds[dclId].add(id);
        entities[id].dynamicComponents.add(DynamicEntityComponent(dcsId, componentId));
    }
    void addComponent(Component)(size_t id, lazy Component component) if (!(isComponentStatic!Component)) {
        size_t dcsId = addDynamicComponentStruct!Component();
        size_t dclId = dynamicComponentStructs[dcsId].id;
        size_t componentId = dynamicComponentLists[dclId].get!(ToList!Component)().addId(component);
        dynamicComponentEntityIds[dclId].add(id);
        entities[id].dynamicComponents.add(DynamicEntityComponent(dcsId, componentId));
    }
    size_t addDynamicComponentStruct(Component)() {
        size_t dcsId = dynamicComponentStructs.findIndex(DynamicComponentStruct(Component.stringof));
        if (dcsId == size_t.max) {
            size_t dclId = dynamicComponentLists.addId(Unknown(ToList!Component()));
            size_t dceId = dynamicComponentEntityIds.addId();
            componentDestructors.add(&(dynamicComponentLists[dclId].get!(ToList!Component)().removeById));
            assert(dclId == dceId);
            //writeln(dceId, " ", dclId, " ", dcsId);
            dynamicComponentStructs.add(DynamicComponentStruct(Component.stringof, dclId));
            dcsId = dynamicComponentStructs.findIndex(DynamicComponentStruct(Component.stringof));
        }
        return dcsId;
    }
    void removeComponent(Component)(size_t id) if (isComponentStatic!Component) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        version (Debug) {
            assert(entities[id].staticComponents[componentId] != size_t.max, "Entity does not have component");
        }
        size_t componentEntityId = entities[id].staticComponents[componentId];
        componentEntityIds[componentId].removeById(componentEntityId);
        static if (findTypes!(Component, StaticGeneralUpdates.TypeSeq).length > 0) {
            size_t entry = entities[id].staticGeneralUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]];
            if (entry != size_t.max) {
                generalUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]].removeById(entry);
                entities[id].staticGeneralUpdates[findTypes!(Component, StaticGeneralUpdates.TypeSeq)[0]] = size_t.max;
            }
        }
        static if (findTypes!(Component, SpecificUpdatesOnlyComponents).length > 0) {
            static foreach (i; findTypes!(Component, SpecificUpdatesOnlyComponents)) {
                size_t entry = entities[id].staticSpecificUpdates[i];
                if (entry != size_t.max) {
                    specificUpdates[i].removeById(entry);
                    entities[id].staticSpecificUpdates[i] = size_t.max;
                }
            }
        }
        static if (findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0) {
            size_t removedId = removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].addId();
            removeIds[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].add(id);
            Component dummy;
            memcpy(
                cast(void*)&removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]][removedId],
                cast(void*)&componentLists[componentId][componentEntityId],
                Component.sizeof
            );
            memcpy(cast(void*)&componentLists[componentId][componentEntityId], cast(void*)&dummy, Component.sizeof);
        }
        static if (config.compact) {
            auto moved = componentLists[componentId].removeById(componentEntityId);
            if (moved.oldId != moved.newId) {
                entities[componentEntityIds[componentId][moved.newId]].staticComponents[componentId] = moved.newId;
                static if (findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0) {
                    movedComponents[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].add(moved);
                }
            }
        } else {
            componentLists[componentId].removeById(componentEntityId);
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
    void removeComponent(Component)(size_t id) if (!(isComponentStatic!Component)) {
        size_t dcs = dynamicComponentStructs.findIndex(DynamicComponentStruct(Component.stringof));
        size_t dec = entities[id].dynamicComponents.findIndex(DynamicEntityComponent(dcs));
        dynamicComponentLists[dynamicComponentStructs[dcs].id].get!(ToList!Component)().remove(entities[id].dynamicComponents[dec].componentId);
        entities[id].dynamicComponents.removeById(dec);
        dynamicComponentEntityIds[dynamicComponentStructs[dcs].id].removeById(entities[id].dynamicComponents[dec].componentId);
    }
    void remove(size_t id) {
        foreach (i, entry; entities[id].staticGeneralUpdates) {
            if (entry != size_t.max) {
                generalUpdates[i].removeById(entry);
            }
        }
        foreach (i, entry; entities[id].staticSpecificUpdates) {
            if (entry != size_t.max) {
                specificUpdates[i].removeById(entry);
            }
        }
        static foreach (componentId, Component; StaticComponents.TypeSeq) {{
            size_t componentEntityId = entities[id].staticComponents[componentId];
            if (componentEntityId != size_t.max) {
                componentEntityIds[componentId].removeById(componentEntityId);
                static if (findTypes!(Component, StaticRemoveUpdates.TypeSeq).length > 0) {
                    size_t removedId = removeUpdates[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].addId();
                    removeIds[findTypes!(Component, StaticRemoveUpdates.TypeSeq)[0]].add(id);
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
        }}
        static if (config.dynamicComponents) {
            foreach (dec; entities[id].dynamicComponents) {
                size_t dclId = dynamicComponentStructs[dec.structId].id;
                dynamicComponentEntityIds[dclId].removeById(dec.componentId);
                componentDestructors[dclId](dec.componentId);
            }
        }
        entities.removeById(id);
    }
    void updateAddUpdateList(Component)(size_t id) if (isComponentStatic!Component) {
        static if (findTypes!(Component, StaticAddUpdates.TypeSeq).length > 0) {
            enum size_t typeId = findTypes!(Component, StaticAddUpdates.TypeSeq)[0];
            size_t addUpdatesId = addUpdates[typeId].addId(id);
            entities[id].staticAddUpdates[typeId] = addUpdatesId;
        }
    }
    void updateViews(Component, bool added)(size_t id) if (isComponentStatic!Component) {
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
    auto ref getComponent(Component)(size_t id) if (
        isComponentStatic!Component &&
        findTypes!(Component, TemplateGeneralUpdates.TypeSeq).length == 0 &&
        findTypes!(Component, SpecificUpdatesOnlyComponents).length == 0 &&
        findTypes!(Component, TemplateGeneralUpdatesMultiple.TypeSeq).length == 0 &&
        findTypes!(Component, SpecificUpdatesOnlyComponentsMultiple).length == 0
    ) {
        version (Debug) {
            assert(entities[id].staticComponents[getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return getComponents!Component()[entities[id].staticComponents[getComponentId!Component()]];
    }
    auto getComponent(Component)(size_t id) if (
        isComponentStatic!Component && (
        findTypes!(Component, TemplateGeneralUpdates.TypeSeq).length > 0 ||
        findTypes!(Component, SpecificUpdatesOnlyComponents).length > 0 ||
        findTypes!(Component, TemplateGeneralUpdatesMultiple.TypeSeq).length > 0 ||
        findTypes!(Component, SpecificUpdatesOnlyComponentsMultiple).length > 0)
    ) {
        version (Debug) {
            assert(entities[id].staticComponents[getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return VirtualComponent!(ECS, Component)(getEntity(id));
    }
    auto ref getComponent(Component)(size_t id) if (!ecs.isComponentStatic!Component) {
        size_t dcs = dynamicComponentStructs.findIndex(DynamicComponentStruct(Component.stringof));
        DynamicEntityComponent dec = entities[id].dynamicComponents.findUnique(DynamicEntityComponent(dcs));
        return dynamicComponentLists[dynamicComponentStructs[dcs].id].get!(ToList!Component)()[dec.componentId];
    }
    auto ref getForced(Component)(size_t id) if (ecs.isComponentStatic!Component) {
        version (Debug) {
            assert(entities[id].staticComponents[getComponentId!Component()] != size_t.max, "Entity does not have component");
        }
        return getComponents!Component()[entities[id].staticComponents[getComponentId!Component()]];
    }
    auto ref getForced(Component)(size_t id) if (!ecs.isComponentStatic!Component) {
        return getComponent!Component(id);
    }
    bool entityHas(Component)(size_t id) if (isComponentStatic!Component) {
        return entities[id].staticComponents[getComponentId!Component()] != size_t.max;
    }
    bool entityHas(Component)(size_t id) if (!ecs.isComponentStatic!Component) {
        size_t dcs = dynamicComponentStructs.findIndex(DynamicComponentStruct(Component.stringof));
        size_t index = entities[id].dynamicComponents.findIndex(DynamicEntityComponent(dcs));
        return index != size_t.max;
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

struct TestStruct2 {
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
    writeln("has int ", entity.has!int());
    entity.remove!int();
    writeln("has int ", entity.has!int());
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
    toSort.sort();
    foreach (size_t i; toSort) {
        write(i, " ");
    }
    writeln();

    alias TestType(T) = VectorList!(Vector, T);
    OrderedList!(TestType, size_t) ol;
    ol.addNoSort(3).addNoSort(2).addNoSort(1).sort();
    foreach (size_t i; ol) {
        writeln(ol.findUnique(i));
    }

    /*ecs.dynamicComponentStructs.addNoSort(DynamicComponentStruct("bla", 3));
    ecs.dynamicComponentStructs.addNoSort(DynamicComponentStruct("zbla", 1));
    ecs.dynamicComponentStructs.addNoSort(DynamicComponentStruct("Tbla", 1));
    ecs.dynamicComponentStructs.addNoSort(DynamicComponentStruct("abla", 2));
    ecs.dynamicComponentStructs.sort();
    foreach (DynamicComponentStruct i; ecs.dynamicComponentStructs) {
        writeln(i.s, " ", i.id);
    }*/

    entity.add(TestStruct2(10));
    entity.get!TestStruct2().testInt = 20;
    foreach (i; ecs.getComponents!TestStruct2()) {
        writeln(i.testInt);
    }
    ecs.remove(entity.entityId);
    //entity.remove!TestStruct2();
    foreach (i; ecs.getComponents!TestStruct2()) {
        writeln(i.testInt);
    }
}