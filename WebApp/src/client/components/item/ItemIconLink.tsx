import styles from "./item.module.css";
import { getItemData, getItemIconUrl, getItemInfoUrl } from "@/client/data/itemStorage";

const ItemIconLink = ({ itemId }: { itemId: number }): JSX.Element => {
    const itemData = getItemData(itemId);
    if (!itemData) return <>Item {itemId}</>;

    return (
        <a
            href={getItemInfoUrl(itemId)}
            target="_blank"
            className={`itemQuality${itemData.qualityId} ${styles.itemIconLink}`}
        >
            <img className={styles.itemIconLinkIcon} src={getItemIconUrl(itemData.iconName)}></img>
            <span className={"itemQuality" + itemData.qualityId}>{`[${itemData?.itemName}]`}</span>
        </a>
    );
};

export default ItemIconLink;
